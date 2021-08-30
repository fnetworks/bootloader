#![feature(asm)]
#![no_std]
#![no_main]

use core::fmt::Write;

mod early_console;
mod interrupts;

#[inline]
unsafe fn hlt() { asm!("hlt"); }
#[inline]
unsafe fn cli() { asm!("cli"); }
#[inline]
unsafe fn sti() { asm!("sti"); }

fn halt_loop() -> ! {
    unsafe {
        loop {
            cli();
            hlt();
        }
    }
}

#[panic_handler]
fn panic_handler(_: &core::panic::PanicInfo) -> ! {
    loop {}
}

#[no_mangle]
pub extern "C" fn kernel_entry() -> ! {
    let mut con = unsafe { early_console::VgaConsole::new(0xB8000) };
    con.clear();
    writeln!(con, "Hello, World!").unwrap();
    halt_loop();
}
