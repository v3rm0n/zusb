const c = @import("c.zig");
const std = @import("std");
const Context = @import("context.zig").Context;
const Device = @import("device.zig").Device;
const fromLibusb = @import("constructor.zig").fromLibusb;

const err = @import("error.zig");

pub const Devices = struct {
    ctx: *Context,
    devices: []?*c.libusb_device,
    i: usize,

    pub fn next(self: *Devices) ?Device {
        if (self.i < self.devices.len) {
            defer self.i += 1;
            return fromLibusb(Device, .{ self.ctx, self.devices[self.i].? });
        } else {
            return null;
        }
    }
};

pub const DeviceList = struct {
    ctx: *Context,
    list: [*c]?*c.libusb_device,
    len: usize,

    pub fn init(ctx: *Context) err.Error!DeviceList {
        var list: [*c]?*c.libusb_device = undefined;
        const n = c.libusb_get_device_list(ctx.raw, &list);

        if (n < 0) {
            return err.errorFromLibusb(@intCast(n));
        } else {
            return DeviceList{
                .ctx = ctx,
                .list = list,
                .len = @intCast(n),
            };
        }
    }

    pub fn deinit(self: DeviceList) void {
        c.libusb_free_device_list(self.list, 1);
    }

    pub fn devices(self: DeviceList) Devices {
        return Devices{
            .ctx = self.ctx,
            .devices = self.list[0..self.len],
            .i = 0,
        };
    }
};
