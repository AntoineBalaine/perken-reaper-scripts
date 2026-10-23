pub const AutomationMode = enum(c_int) {
    trim,
    read,
    touch,
    latch,
    preview,
    write,
};
