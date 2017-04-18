/**
 Created by Sinisa Drpa on 7/28/16.

 Projection is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License or any later version.

 Projection is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Projection.  If not, see <http://www.gnu.org/licenses/>
 */

import ATCKit
import Foundation
import PROJ4
import Mathematics
import Measure

public final class PROJ {

    public enum IError: Error {
        case initFailed(code: Int, message: String)
        case transformFailed(code: Int, message: String)
    }

    private let wgs840: UnsafeMutableRawPointer // projPJ
    private let mercator: UnsafeMutableRawPointer // projPJ

    public init() {
        // http://spatialreference.org/ref/sr-org/7483/
        // https://trac.osgeo.org/proj/wiki/GenParms
        let WGS840 = "+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs"
        guard let wgs840 = pj_init_plus(WGS840) else {
            fatalError()
        }
        self.wgs840 = wgs840

        let WebMercator =
        "+proj=lcc +lat_1=41 +lat_2=46 +lat_0=43 +lon_0=20 +x_0=0 +y_0=0 +ellps=WGS84 +datum=WGS84 +units=m +no_defs"
        //"+proj=merc +a=6378137 +b=6378137 +lat_ts=0.0 +lon_0=0.0 +x_0=0.0 +y_0=0 +k_0=1.0 +units=m +nadgrids=@null +wktext +no_defs"
        guard let mercator = pj_init_plus(WebMercator) else {
            fatalError()
        }
        self.mercator = mercator
    }

    deinit {
        pj_free(self.wgs840)
        pj_free(self.mercator)
    }

    public func world(from coordinate: Coordinate) -> WorldCoordinate? {
        let lat = Double(Radian(coordinate.latitude))
        let lon = Double(Radian(coordinate.longitude))
        do {
            guard let transformed = try self.transform(points: [Vector3(x: lon, y: lat, z: 0.0)],
                                                       source: self.wgs840,
                                                       target: self.mercator).first else {
                                                        fatalError()
            }
            return WorldCoordinate(x: Meter(transformed.x), y: Meter(transformed.y))
        }
        catch {
            fatalError(error.localizedDescription)
        }
    }

    public func coordinate(from world: WorldCoordinate) -> Coordinate? {
        do {
            let points = [Vector3(x: Double(world.x), y: Double(world.y), z: 0.0)]
            guard let transformed = try self.transform(points: points, source: self.mercator, target: self.wgs840).first else {
                fatalError()
            }
            return Coordinate(latitude: Degree(Radian(transformed.y)), longitude: Degree(Radian(transformed.x)))
        }
        catch {
            fatalError(error.localizedDescription)
        }
    }

    // https://trac.osgeo.org/proj/wiki/ProjAPI
    // Why use pj_inv() and pj_fwd() instead of pj_transform()? - http://lists.maptools.org/pipermail/proj/2007-June/002969.html
    // pj_fwd and pj_inv are obsolete
    private func transform(points: [Vector3], source: UnsafeMutableRawPointer, target: UnsafeMutableRawPointer) throws -> [Vector3] {
        var xs = points.map { $0.x }
        var ys = points.map { $0.y }
        var zs = points.map { $0.z }
        let retval = pj_transform(source, target, points.count, 1, &xs, &ys, &zs)
        if retval != 0 {
            throw IError.transformFailed(code: Int(retval), message: PROJ.errorMessage(errno: retval))
        }
        return xs.enumerated().map { index, x in
            return Vector3(x: x, y: ys[index], z: zs[index])
        }
    }

    private static func errorMessage(errno: Int32? = nil) -> String {
        var errorCode: Int32
        if let errno = errno {
            errorCode = errno
        } else {
            errorCode = pj_get_errno_ref().pointee
        }
        guard let stringWithErrorCode = pj_strerrno(errorCode) else {
            fatalError("string == nil")
        }
        guard let message = String(validatingUTF8: UnsafePointer<CChar>(stringWithErrorCode)) else {
            fatalError("message == nil")
        }
        return message;
    }
}
