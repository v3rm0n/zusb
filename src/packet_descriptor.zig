const c = @import("c.zig");
const err = @import("error.zig");

pub const PacketDescriptors = struct {
    transfer: *c.libusb_transfer,
    iter: []c.struct_libusb_iso_packet_descriptor,
    i: usize,

    pub fn init(transfer: *c.libusb_transfer, iter: []c.struct_libusb_iso_packet_descriptor) PacketDescriptors {
        return .{ .transfer = transfer, .iter = iter, .i = 0 };
    }

    pub fn next(self: *PacketDescriptors) ?PacketDescriptor {
        if (self.i < self.iter.len) {
            defer self.i += 1;
            return PacketDescriptor{ .transfer = self.transfer, .descriptor = &self.iter[self.i], .idx = self.i };
        } else {
            return null;
        }
    }
};

pub const PacketDescriptor = struct {
    transfer: *c.libusb_transfer,
    descriptor: *c.struct_libusb_iso_packet_descriptor,
    idx: usize,

    pub fn buffer(self: *const PacketDescriptor) []u8 {
        const c_buffer = c.libusb_get_iso_packet_buffer_simple(self.transfer, @intCast(self.idx));
        return c_buffer[0..self.descriptor.actual_length];
    }

    pub fn isCompleted(self: *const PacketDescriptor) bool {
        return self.descriptor.status == c.LIBUSB_TRANSFER_COMPLETED;
    }

    pub fn status(self: *const PacketDescriptor) err.Error {
        return err.errorFromLibusb(@intCast(self.descriptor.status));
    }
};
