const std = @import("std");
const io = std.io;
const File = std.fs.File;
const ArrayList = std.ArrayList;

const Bf = struct {
    const TAPE_LEN = 30000;
    
    stdin: File,
    stdout: File,

    pc: usize,
    
    tape: [TAPE_LEN]u8,
    ptr: usize, // undefined behaviour if ptr is outside the bounds of tape

    stack: ArrayList(usize),
    braces: [TAPE_LEN]usize,

    pub fn init(allocator: *std.mem.Allocator) Bf {
        return Bf {
            .pc = 0,
            .tape = [_]u8{0} ** TAPE_LEN,
            .ptr = 0,
            .stack = ArrayList(usize).init(allocator),
            .braces = [_]usize{0} ** TAPE_LEN,
            .stdin = io.getStdIn() catch unreachable,
            .stdout = io.getStdOut() catch unreachable,
        };
    }

    pub fn deinit(self: *Bf) void {
        self.stack.deinit();
    }

    pub fn run(self: *Bf, rom: []u8) !void {
        self.pc = 0;

        // match the braces first
        while (true) {
            const instruction = rom[self.pc];
            if (instruction == '[') {
                try self.stack.append(self.pc);
            } 
            else if (instruction == ']') {
                if (self.stack.popOrNull()) |open| {
                    self.braces[self.pc] = open;
                    self.braces[open] = self.pc;
                } 
                else {
                    std.debug.warn("unmatched ']' at byte {}", self.pc);
                    return;
                }
            }

            self.pc += 1;
            if (self.pc == rom.len) {
                if (self.stack.popOrNull()) |open| {
                    std.debug.warn("unmatched '[' at byte {}", open);
                    return;
                }
                break;
            }
        }

        // now execute
        self.pc = 0;
        while (self.pc != rom.len) : (self.pc += 1) try self.execute(rom[self.pc]);
    }

    fn execute(self: *Bf, instruction: u8) !void {
        switch (instruction) {
            '>' => self.ptr +%= 1,
            '<' => self.ptr -%= 1,
            '+' => self.tape[self.ptr] +%= 1,
            '-' => self.tape[self.ptr] -%= 1,
            '.' => {
                const ch = if (self.tape[self.ptr] == 10) '\n' else self.tape[self.ptr];
                try self.stdout.write([_]u8{ch});
            },
            ',' => {
                var buf = [_]u8{0};
                _ = try self.stdin.read(buf[0..]);
                self.tape[self.ptr] = if (buf[0] == '\n') 10 else buf[0];
            },
            '[' => {
                if (self.tape[self.ptr] == 0) self.pc = self.braces[self.pc];
            },
            ']' => {
                if (self.tape[self.ptr] != 0) self.pc = self.braces[self.pc];
            },
            else => {}, // it's a comment
        }
    }
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.direct_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.warn("no file input\n");
        std.os.exit(1);
    }

    const rom = try io.readFileAlloc(allocator, args[1]);
    defer allocator.free(rom);

    var bf = Bf.init(allocator);
    defer bf.deinit();

    try bf.run(rom);
}