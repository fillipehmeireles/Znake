const std = @import("std");
const rl = @cImport({
    @cInclude("raylib.h");
});

const W_WIDTH: c_int = 800;
const W_HEIGHT: c_int = 450;

const GAME_STAGE = enum {
    GAMEPLAY,
    GAME_OVER,
};
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

pub fn GameOverStage() void {
    rl.ClearBackground(rl.BLACK);
    rl.DrawText("GAME OVER", W_WIDTH - (W_WIDTH - 30), W_HEIGHT / 2, 120, rl.RED);
}

const GameObjects = struct {
    rec: rl.Rectangle,
    sprite: rl.Texture2D,
    color: rl.Color,

    pub fn init(x: f32, y: f32, w: f32, h: f32, color: rl.Color) GameObjects {
        return GameObjects{
            .rec = rl.Rectangle{ .x = x, .y = y, .width = w, .height = h },
            .sprite = undefined,
            .color = color,
        };
    }
    pub fn draw(self: GameObjects) void {
        rl.DrawRectangleRec(self.rec, self.color);
    }
};

pub const Snake = struct {
    allocator: std.mem.Allocator,
    snode: ?*SNode,

    pub const SNode = struct {
        previous_piece: ?*SNode,
        next_piece: ?*SNode,
        piece: GameObjects,
    };

    pub fn initHead(self: *Snake) !void {
        const new_snode = try self.allocator.create(SNode);
        new_snode.* = .{
            .previous_piece = null,
            .next_piece = null,
            .piece = GameObjects.init(100, 100, 20, 20, rl.GREEN),
        };

        self.snode = new_snode;
    }

    pub fn sAppend(self: *Snake) !void {
        var l_tail: ?*SNode = null;
        var p = self.snode;
        while (p) |s| : (p = s.next_piece) {
            l_tail = p;
        }

        if (l_tail) |s| {
            const new_snode = try self.allocator.create(SNode);
            new_snode.* = .{
                .previous_piece = l_tail,
                .next_piece = null,
                .piece = GameObjects.init(s.piece.rec.x + s.piece.rec.width, s.piece.rec.y, 20, 20, rl.WHITE),
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

    pub fn moveSnake(self: *Snake, direction: rl.KeyboardKey) void {
        const head = self.snode orelse return;
        var step_y: f32 = head.piece.rec.y;
        var step_x: f32 = head.piece.rec.x;
        if (direction == rl.KEY_DOWN) {
            step_y += head.piece.rec.height;
        } else if (direction == rl.KEY_LEFT) {
            step_x -= head.piece.rec.width;
        } else if (direction == rl.KEY_RIGHT) {
            step_x += head.piece.rec.width;
        } else if (direction == rl.KEY_UP) {
            step_y -= head.piece.rec.height;
        }

        var np = head.next_piece;

        if (np) |t| {
            if (t.piece.rec.x == step_x and t.piece.rec.y == step_y) {
                return;
            }
        } else {
            head.piece.rec.x = step_x;
            head.piece.rec.y = step_y;
        }
        var l_tail: ?*SNode = null;
        while (np) |s| : (np = s.next_piece) {
            l_tail = np;
        }
        while (l_tail) |lt| : (l_tail = lt.previous_piece) {
            if (lt.previous_piece) |pp| {
                lt.piece.rec.y = pp.piece.rec.y;
                lt.piece.rec.x = pp.piece.rec.x;
            } else {
                lt.piece.rec.y = step_y;
                lt.piece.rec.x = step_x;
            }
        }
    }

    pub fn checkSnakeOnWall(self: *Snake) !void {
        const head = self.snode orelse return;
        if (head.piece.rec.x <= 0) {
            head.piece.rec.x = W_WIDTH - head.piece.rec.width;
        } else if (head.piece.rec.x >= W_WIDTH) {
            head.piece.rec.x = 0;
        }

        if (head.piece.rec.y <= 0) {
            head.piece.rec.y = W_HEIGHT - head.piece.rec.height;
        } else if (head.piece.rec.y >= W_HEIGHT) {
            head.piece.rec.y = 0;
        }
    }

    pub fn checkSnakeHeadTailCollision(self: *Snake, current_game_stage: *GAME_STAGE) void {
        const head = self.snode orelse return;
        var tail = head.next_piece;
        while (tail) |s| : (tail = s.next_piece) {
            if (rl.CheckCollisionRecs(head.piece.rec, s.piece.rec)) {
                current_game_stage.* = GAME_STAGE.GAME_OVER;
            }
        }
    }

    pub fn checkSnakeEated(self: *Snake, apple: *Apple) !void {
        const head = self.snode orelse return;
        if (rl.CheckCollisionRecs(head.piece.rec, apple.game_obj.rec)) {
            try self.sAppend();
            apple.active = false;
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
            self.game_obj.draw();
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
    sll.* = .{ .allocator = allocator, .snode = null };
    try sll.initHead();
    try sll.sAppend();

    var apple = Apple{
        .game_obj = GameObjects.init(0, 0, 10, 10, rl.RED),
        .active = false,
    };

    var current_game_stage = GAME_STAGE.GAMEPLAY;
    rl.InitWindow(game_screen.width, game_screen.height, "Znake");
    const interval: f32 = 2;
    var timer: f32 = 0;

    defer rl.CloseWindow();
    rl.SetTargetFPS(60);
    while (!rl.WindowShouldClose()) {
        rl.BeginDrawing();
        defer rl.EndDrawing();
        const dt = rl.GetFrameTime();
        switch (current_game_stage) {
            GAME_STAGE.GAMEPLAY => {
                timer += dt;
                if (timer >= interval) {
                    try apple.update();
                    timer = 0;
                }
                var key_pressed: rl.KeyboardKey = 0;
                if (rl.IsKeyDown(rl.KEY_DOWN)) key_pressed = rl.KEY_DOWN;
                if (rl.IsKeyDown(rl.KEY_UP)) key_pressed = rl.KEY_UP;
                if (rl.IsKeyDown(rl.KEY_LEFT)) key_pressed = rl.KEY_LEFT;
                if (rl.IsKeyDown(rl.KEY_RIGHT)) key_pressed = rl.KEY_RIGHT;
                if (key_pressed != 0) {
                    sll.moveSnake(key_pressed);
                    sll.checkSnakeHeadTailCollision(&current_game_stage);
                    try sll.checkSnakeOnWall();
                    try sll.checkSnakeEated(&apple);
                }

                sll.drawSnake();
                apple.draw();
            },
            GAME_STAGE.GAME_OVER => GameOverStage(),
        }
        rl.ClearBackground(rl.BLACK);
    }
}
