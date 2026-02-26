//! MIME / content-type utilities.
//!
//! Maps file extensions to httpz.ContentType values for use when serving
//! embedded static assets.

const httpz = @import("httpz");

pub fn contentTypeForPath(path: []const u8) httpz.ContentType {
    if (endsWith(path, ".js")) return .JS;
    if (endsWith(path, ".css")) return .CSS;
    if (endsWith(path, ".html")) return .HTML;
    if (endsWith(path, ".json")) return .JSON;
    if (endsWith(path, ".svg")) return .SVG;
    if (endsWith(path, ".png")) return .PNG;
    if (endsWith(path, ".ico")) return .ICO;
    return .BINARY;
}

fn endsWith(path: []const u8, ext: []const u8) bool {
    return path.len >= ext.len and
        std.mem.eql(u8, path[path.len - ext.len ..], ext);
}

const std = @import("std");
