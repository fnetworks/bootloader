use core::fmt;

#[derive(Copy, Clone)]
#[repr(u8)]
#[allow(dead_code)]
enum Color {
    Black = 0,
    Blue = 1,
    Green = 2,
    Cyan = 3,
    Red = 4,
    Magenta = 5,
    Brown = 6,
    LightGrey = 7,
    DarkGrey = 8,
    LightBlue = 9,
    LightGreen = 10,
    LightCyan = 11,
    LightRed = 12,
    LightMagenta = 13,
    LightBrown = 14,
    White = 15,
}

#[repr(packed)]
#[derive(Copy, Clone)]
struct Cell {
    text: u8,
    color: u8,
}

impl Cell {
    fn new(text: u8, foreground: Color, background: Color) -> Self {
        Self {
            text,
            color: (background as u8) << 4 | (foreground as u8),
        }
    }
}

impl Default for Cell {
    fn default() -> Self {
        Self::new(b' ', Color::White, Color::Black)
    }
}

const WIDTH: usize = 80;
const HEIGHT: usize = 25;

pub struct VgaConsole {
    buffer: *mut Cell,
    x: usize,
    y: usize,
}

impl VgaConsole {
    pub unsafe fn new(at: usize) -> Self {
        Self {
            buffer: at as *mut Cell,
            x: 0,
            y: 0,
        }
    }

    unsafe fn write_cell(&mut self, x: usize, y: usize, cell: Cell) {
        self.buffer.offset((y * WIDTH + x) as isize).write_volatile(cell);
    }

    unsafe fn read_cell(&self, x: usize, y: usize) -> Cell {
        self.buffer.offset((y * WIDTH + x) as isize).read_volatile()
    }

    fn newline(&mut self) {
        self.y += 1;
        self.y = 0;

        if self.y >= HEIGHT {
            for line in 1..HEIGHT {
                for x in 0..WIDTH {
                    unsafe { self.write_cell(x, line - 1, self.read_cell(x, line)); }
                }
            }
            for x in 0..WIDTH {
                unsafe { self.write_cell(x, HEIGHT - 1, Cell::default()); }
            }
            self.y -= 1;
        }
    }

    pub fn clear(&mut self) {
        for row in 0..HEIGHT {
            for col in 0..WIDTH {
                unsafe { self.write_cell(col, row, Cell::default()); }
            }
        }

        self.x = 0;
        self.y = 0;
    }

    pub fn write_char(&mut self, ch: u8) {
        match ch {
            b'\n' => self.newline(),
            b'\r' => {},
            b'\t' => {
                for _ in 0..4 {
                    self.write_char(b' ');
                }
            }
            _ => {
                if self.x >= WIDTH {
                    self.newline();
                }
                unsafe { self.write_cell(self.x, self.y, Cell::new(ch, Color::White, Color::Black)); }
                self.x += 1;
            }
        }
    }

    fn write_string(&mut self, string: &[u8]) {
        for chr in string {
            self.write_char(*chr);
        }
    }
}

impl fmt::Write for VgaConsole {
    fn write_str(&mut self, s: &str) -> fmt::Result {
        self.write_string(s.as_bytes());
        Ok(())
    }
}
