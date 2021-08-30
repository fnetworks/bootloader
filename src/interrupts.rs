#[repr(packed)]
#[derive(Copy, Clone)]
struct InterruptGate {
    offset_low: u16,
    segment_selector: u16,
    zero: u8,
    attributes: u8,
    offset_high: u16,
}

#[repr(packed)]
#[derive(Copy, Clone)]
struct IdtPointer {
    size: u16,
    offset: u32,
}

static mut IDT: [InterruptGate; 256] = [
    InterruptGate {
        offset_low: 0,
        segment_selector: 0,
        zero: 0,
        attributes: 0,
        offset_high: 0,
    };
    256
];

static mut IDT_PTR: IdtPointer = IdtPointer {
    size: 0,
    offset: 0,
};

pub fn load_idt() {
    unsafe {
        IDT_PTR.size = core::mem::size_of_val(&IDT) as u16;
        IDT_PTR.offset = core::ptr::addr_of!(IDT) as u32;
        asm!("lidt, [{}]", sym IDT_PTR, options(nostack, preserves_flags));
    }
}

