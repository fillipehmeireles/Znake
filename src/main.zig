const std = @import("std");
const rl = @cImport({
    @cInclude("raylib.h");
});

const W_WIDTH: c_int = 800;
const W_HEIGHT: c_int = 450;

const GameScreen = struct {
    width: c_int,
    height: c_int,

    pub fn init(w: c_int, h: c_int) GameScreen {
        return GameScreen{
            .width = w,
            .height = h,
        };
    }
};

const GameObjects = struct {
    rec: rl.Rectangle,
    sprite: rl.Texture2D,

    pub fn init(x: f32, y: f32, w: f32, h: f32) GameObjects {
        return GameObjects{
            .rec = rl.Rectangle{ .x = x, .y = y, .width = w, .height = h },
            .sprite = undefined,
        };
    }
    pub fn draw(self: GameObjects) void {
        rl.DrawRectangleRec(self.rec, rl.WHITE);
    }
};

pub const Snake = struct {
    allocator: std.mem.Allocator,
    snode: ?*SNode,
    step: f32,

    pub const SNode = struct {
        next_piece: ?*SNode,
        piece: GameObjects,
    };

    pub fn init(allocator: std.mem.Allocator) Snake {
        return .{
            .allocator = allocator,
            .snode = null,
        };
    }

    pub fn initHead(self: *Snake) !void {
        const new_snode = try self.allocator.create(SNode);
        new_snode.* = .{
            .next_piece = null,
            .piece = GameObjects.init(100, 100, 20, 20),
        };

        self.snode = new_snode;
    }

    pub fn sAppend(self: *Snake) !void {
        if (self.snode) |s| {
            const new_snode = try self.allocator.create(SNode);
            new_snode.* = .{
                .next_piece = null,
                .piece = GameObjects.init(s.piece.rec.x + s.piece.rec.width, s.piece.rec.y, 20, 20),
            };

            s.next_piece = new_snode;
        }
    }

    pub fn drawSnake(self: *Snake) void {
        var p = self.snode;
        while (p) |s| : (p = s.next_piece) {
            s.piece.draw();
        }
    }

    pub fn destroySnake(self: *Snake) void {
        var p = self.snode;
        while (p) |s| : (p = s.next_piece) {
            self.allocator.destroy(s);
        }
        self.snode = null;
    }

    pub fn moveSnake(self: *Snake, direction: c_int) void {
        // TODO move head and set tail to previous head pos
        if (direction == rl.KEY_DOWN) {
            var p = self.snode;
            while (p) |s| : (p = s.next_piece) {
                s.piece.rec.y += self.step;
            }
        } else if (direction == rl.KEY_LEFT) {
            var p = self.snode;
            while (p) |s| : (p = s.next_piece) {
                s.piece.rec.x -= self.step;
            }
        }
    }
};

const Apple = struct {
    game_obj: GameObjects,
    active: bool,

    pub fn update(self: *Apple) !void {
        self.active = true;
        var s: u64 = undefined;

        try std.posix.getrandom(std.mem.asBytes(&s));
        var prng = std.rand.DefaultPrng.init(blk: {
            const seed: u64 = s;
            break :blk seed;
        });
        const rand = prng.random();

        const recx: i32 = @intFromFloat(self.game_obj.rec.width);
        const recy: i32 = @intFromFloat(self.game_obj.rec.height);
        const yy = rand.intRangeAtMost(i32, 1, W_HEIGHT - recx);
        const xx = rand.intRangeAtMost(i32, 1, W_WIDTH - recy);
        const x: f32 = @floatFromInt(xx);
        const y: f32 = @floatFromInt(yy);

        self.game_obj.rec.x = x;
        self.game_obj.rec.y = y;
    }
    pub fn draw(self: Apple) void {
        if (self.active) {
            rl.DrawRectangleRec(self.game_obj.rec, rl.RED);
        }
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    const game_screen = GameScreen.init(W_WIDTH, W_HEIGHT);
    var sll = try allocator.create(Snake);
    defer sll.destroySnake();
    defer allocator.destroy(sll);
    sll.* = .{ .allocator = allocator, .snode = null, .step = 3 };
    try sll.initHead();
    try sll.sAppend();

    var apple = Apple{
        .game_obj = GameObjects.init(0, 0, 10, 10),
        .active = false,
    };
    rl.InitWindow(game_screen.width, game_screen.height, "Znake");
    const interval: f32 = 1;
    var timer: f32 = 0;

    defer rl.CloseWindow();
    rl.SetTargetFPS(60);
    while (!rl.WindowShouldClose()) {
        rl.BeginDrawing();
        defer rl.EndDrawing();
        rl.ClearBackground(rl.BLACK);
        const dt = rl.GetFrameTime();
        timer += dt;
        if (timer >= interval) {
            try apple.update();
            timer = 0;
        }
        const pressed = rl.GetKeyPressed();
        if (pressed != 0) {
            sll.moveSnake(pressed);
        }

        sll.drawSnake();
        apple.draw();
    }
}
