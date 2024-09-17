const c = @import("c.zig");
const std = @import("std");
const Allocator = std.mem.Allocator;
const DeviceHandle = @import("device_handle.zig").DeviceHandle;

const err = @import("error.zig");

/// WIP
pub fn Transfer(comptime T: type) type {
    return struct {
        const Self = @This();

        const libusb_transfer = extern struct {
            dev_handle: *c.libusb_device_handle,
            flags: u8,
            endpoint: u8,
            @"type": u8,
            timeout: c_uint,
            status: c.libusb_transfer_status,
            length: c_int,
            actual_length: c_int,
            callback: fn (*libusb_transfer) callconv(.C) void,
            user_data: ?*anyopaque,
            buffer: [*c]u8,
            num_iso_packets: c_int,
            iso_packet_desc: [0]c.libusb_iso_packet_descriptor, // TODO: Variable Length Array
        };

        allocator: *Allocator,
        transfer: *libusb_transfer,
        user_data: T,
        callback: fn (*Self) void,

        pub fn deinit(self: *const Self) void {
            c.libusb_free_transfer(@ptrCast(self.transfer));
            self.allocator.destroy(self);
        }

        pub fn submit(self: *Self) err.Error!void {
            self.transfer.user_data = self;
            try err.failable(c.libusb_submit_transfer(@ptrCast(self.transfer)));
        }

        pub fn cancel(self: *Self) err.Error!void {
            try err.failable(c.libusb_cancel_transfer(@ptrCast(self.transfer)));
        }

        pub fn buffer(self: Self) []u8 {
            const length = std.math.cast(usize, self.transfer.length) orelse @panic("Buffer length too large");
            return self.transfer.buffer[0..length];
        }

        pub fn fillInterrupt(
            allocator: *Allocator,
            handle: *DeviceHandle,
            endpoint: u8,
            buf: []u8,
            callback: fn (*Self) void,
            user_data: T,
            timeout: u64,
        ) (Allocator.err.Error || err.Error)!*Self {
            const opt_transfer: ?*libusb_transfer = @ptrFromInt(@intFromPtr(c.libusb_alloc_transfer(0)));

            if (opt_transfer) |transfer| {
                transfer.*.dev_handle = handle.handle;
                transfer.*.endpoint = endpoint;
                transfer.*.@"type" = c.LIBUSB_TRANSFER_TYPE_INTERRUPT;
                transfer.*.timeout = std.math.cast(c_uint, timeout) orelse @panic("Timeout too large");
                transfer.*.buffer = buf.ptr;
                transfer.*.length = std.math.cast(c_int, buf.len) orelse @panic("Length too large");
                transfer.*.callback = callbackRaw;

                var self = try allocator.create(Self);
                self.* = Self{
                    .allocator = allocator,
                    .transfer = transfer,
                    .user_data = user_data,
                    .callback = callback,
                };

                return self;
            } else {
                return error.OutOfMemory;
            }
        }

        export fn callbackRaw(transfer: *libusb_transfer) void {
            const self: *Self = @ptrFromInt(@intFromPtr(transfer.user_data.?));
            self.callback(self);
        }
    };
}
