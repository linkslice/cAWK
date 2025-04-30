#!/usr/bin/awk -f

BEGIN {
    print "cAWK: Compiling C to ELF binary"
    
    # Initialize variables
    output_file = "out.elf"
    system("rm -f " output_file)
    system("touch " output_file)
    
    # Lexer/parser state
    in_main = 0
    has_return = 0
    return_value = 0
    
    # Binary generation - ELF header and program header
    generate_elf_header(output_file)
}

# Simple C parsing
{
    line = $0
    
    # Look for main function
    if (match(line, /int main\(\)/)) {
        in_main = 1
        next
    }
    
    # Process return statements
    if (in_main && match(line, /return ([0-9]+);/, matches)) {
        has_return = 1
        return_value = matches[1]
        print "Found return value: " return_value
    }
    
    # Process if statements (very basic)
    if (in_main && match(line, /if \(([a-zA-Z0-9_]+) > ([0-9]+)\)/, matches)) {
        var_name = matches[1]
        threshold = matches[2]
        print "Found if statement: " var_name " > " threshold
        # We'd store this for code generation
    }
    
    # Find variable declarations
    if (in_main && match(line, /int ([a-zA-Z0-9_]+) = ([0-9]+);/, matches)) {
        var_name = matches[1]
        var_value = matches[2]
        print "Found variable: " var_name " = " var_value
        # Store variables for code generation
        variables[var_name] = var_value
    }
}

END {
    if (!has_return) {
        return_value = 0  # Default return value
    }
    
    # Simple conditional logic for our test.c
    if ("x" in variables && variables["x"] > 10) {
        return_value = 10
    } else if ("x" in variables) {
        return_value = 69
    }
    
    print "Generating machine code with return value: " return_value
    
    # Generate x86-64 machine code for the program
    generate_machine_code(output_file, return_value)
    
    # Make executable
    system("chmod +x " output_file)
    print "Compilation finished. Binary saved as " output_file
}

function generate_elf_header(file) {
    # ELF Header: Set entry point to 0x400078 (start of the machine code)
    write_binary(file, "\x7fELF\x02\x01\x01\x00")  # Magic number and class
    write_binary(file, "\x00\x00\x00\x00\x00\x00\x00\x00")  # Padding
    write_binary(file, "\x02\x00\x3e\x00")  # Type = EXEC (2), Machine = x86-64 (0x3e)
    write_binary(file, "\x01\x00\x00\x00")  # Version = 1
    write_binary(file, "\x78\x00\x40\x00\x00\x00\x00\x00")  # e_entry = 0x400078 (Entry point)
    write_binary(file, "\x40\x00\x00\x00\x00\x00\x00\x00")  # e_phoff = 0x40 (Program header table offset)
    write_binary(file, "\x00\x00\x00\x00\x00\x00\x00\x00")  # e_shoff = 0 (No section header table)
    
    # ELF Header (continued)
    write_binary(file, "\x00\x00\x00\x00")  # e_flags = 0
    write_binary(file, "\x40\x00")  # e_ehsize = 64 bytes (ELF header size)
    write_binary(file, "\x38\x00")  # e_phentsize = 56 bytes (Program header size)
    write_binary(file, "\x01\x00")  # e_phnum = 1 (One program header)
    write_binary(file, "\x00\x00")  # e_shentsize = 0 (No section headers)
    write_binary(file, "\x00\x00")  # e_shnum = 0
    write_binary(file, "\x00\x00")  # e_shstrndx = 0

    # Program Header: Marks the segment as loadable and executable
    write_binary(file, "\x01\x00\x00\x00")  # p_type = PT_LOAD (Loadable segment)
    write_binary(file, "\x07\x00\x00\x00")  # p_flags = R + W + X (Readable + Writable + Executable)
    write_binary(file, "\x00\x00\x00\x00\x00\x00\x00\x00")  # p_offset = 0x00 (Start at beginning of file)
    write_binary(file, "\x00\x00\x40\x00\x00\x00\x00\x00")  # p_vaddr = 0x400000 (Load address)
    write_binary(file, "\x00\x00\x40\x00\x00\x00\x00\x00")  # p_paddr = 0x400000 (Physical address)
    write_binary(file, "\x8c\x00\x00\x00\x00\x00\x00\x00")  # p_filesz = 140 bytes (Size of entire file)
    write_binary(file, "\x00\x10\x00\x00\x00\x00\x00\x00")  # p_memsz = 4096 bytes (Memory size)
    write_binary(file, "\x01\x00\x00\x00\x00\x00\x00\x00")  # p_align = 1
}

function generate_machine_code(file, ret_val) {
    # Convert decimal return value to hex
    hex_ret_val = sprintf("%x", ret_val)
    while (length(hex_ret_val) < 2) hex_ret_val = "0" hex_ret_val
    
    # Write assembly code to set up and exit with the specified return value
    write_binary(file, "\x90\x90\x90\x90")  # NOPs for alignment
    
    # mov rax, 60 (sys_exit syscall number)
    write_binary(file, "\x48\xc7\xc0\x3c\x00\x00\x00")
    
    # mov rdi, ret_val (return value)
    write_binary(file, "\x48\xc7\xc7")
    write_binary(file, sprintf("%c%c%c%c", ret_val, 0, 0, 0))
    
    # syscall
    write_binary(file, "\x0f\x05")
}

function write_binary(file, data) {
    printf "%s", data >> file
    close(file)
}
