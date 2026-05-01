//! Auth token generation and validation.
//!
//! Generates a 64-character hex token from 32 cryptographically random bytes
//! at server startup. The token is printed in the startup URL so the user can
//! click through and authenticate. Subsequent requests are validated against
//! a session cookie set on first use.

const std = @import("std");

pub const Token = struct {
    token: [64]u8 = undefined,

    pub fn generate(self: *Token) void {
        var bytes: [32]u8 = undefined;
        var prng = std.Random.Xoshiro256.init(0x1234567890abcdef);
        prng.random().bytes(&bytes);
        self.token = std.fmt.bytesToHex(bytes, .lower);
    }
    pub fn validate(self: *const Token, input: []const u8) bool {
        return std.mem.eql(u8, &self.token, input);
    }
};
