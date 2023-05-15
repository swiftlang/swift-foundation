use std::convert::TryInto;
use std::ffi::CString;
//use std::mem;
use libc::c_uint;

extern "C" {
    fn mach_absolute_time() -> u64;
}

#[cfg(target_os = "macos")]
fn nanotime(tv: *mut libc::timespec) {
    let now = mach_absolute_time();
    *(tv).tv_sec = now / 1000000000;
    *(tv).tv_nsec = now - (*(tv).tv_sec * 1000000000);
}

#[cfg(any(target_os = "linux", target_family = "unix"))]
fn nanotime(tv: *mut libc::timespec) {
    unsafe {
        libc::clock_gettime(libc::CLOCK_MONOTONIC, tv);
    }
}


#[cfg(any(target_os = "linux", target_family="unix"))]
fn read_random(buffer: *mut libc::c_void, numBytes: libc::size_t) {
    let file_path = CString::new("/dev/urandom").unwrap();
    unsafe {
        let fd = libc::open(file_path.as_ptr() as *const i8, libc::O_RDONLY);
        libc::read(fd, buffer, numBytes);
        libc::close(fd);
    }
}

fn read_node(node: *mut u8) {
    read_random(node as *mut libc::c_void, 6);
    unsafe {
        *node.offset(0) |= 0x01;
    }
}


fn read_time() -> u64
{
    let mut tv: libc::timespec = libc::timespec{tv_sec: 0, tv_nsec: 0};

    nanotime(&mut tv as *mut libc::timespec);

    return ((tv.tv_sec * 10000000) + (tv.tv_nsec / 100) + 0x01B21DD213814000).try_into().unwrap();
}

const UUID_NULL: [libc::c_uchar;16] = [0;16];
const SIZE_OF_UUID_T: libc::size_t = 16;//mem::size_of::<[libc::c_uchar; 16]>();
const SIZE_OF_UUID_STRING_T: libc::size_t = 37;//mem::size_of::<[libc::c_char; 37]>();

#[no_mangle]
pub unsafe extern "C" fn uuid_clear(uu: *mut libc::c_void)
{
    libc::memset(uu, 0, SIZE_OF_UUID_T);
}

#[no_mangle]
pub unsafe extern "C" fn uuid_compare(uu1: *mut libc::c_void, uu2: *mut libc::c_void) -> libc::c_int {
    return libc::memcmp(uu1, uu2, SIZE_OF_UUID_T);
}

#[no_mangle]
pub unsafe extern "C" fn uuid_copy(dst: *mut libc::c_void, src: *const libc::c_void)
{
    libc::memcpy(dst, src, SIZE_OF_UUID_T);
}

#[no_mangle]
pub unsafe extern "C" fn uuid_generate_random(out: *mut libc::c_int)
{
    read_random(out as *mut libc::c_void, SIZE_OF_UUID_T);

    *out.offset(6) = (*out.offset(6) & 0x0F) | 0x40;
    *out.offset(8) = (*out.offset(8) & 0x3F) | 0x80;
}

#[no_mangle]
pub unsafe extern "C" fn uuid_generate_time(out: *mut u8)
{
    let mut time: u64 = 0;

    read_node(out.offset(10));
    read_random(out.offset(8) as *mut libc::c_void, 2);

    time = read_time();
    *out.offset(0) = (time >> 24) as u8;
    *out.offset(1) = (time >> 16) as u8;
    *out.offset(2) = (time >> 8) as u8;
    *out.offset(3) = time as u8;
    *out.offset(4) = (time >> 40) as u8;
    *out.offset(5) = (time >> 32) as u8;
    *out.offset(6) = (time >> 56) as u8;
    *out.offset(7) = (time >> 48) as u8;

    *out.offset(6) = (*out.offset(6) & 0x0F) | 0x10;
    *out.offset(8) = (*out.offset(8) & 0x3F) | 0x80;
}

#[no_mangle]
pub unsafe extern "C" fn uuid_generate(out: *mut libc::c_int)
{
    uuid_generate_random(out);
}

#[no_mangle]
pub unsafe extern "C" fn uuid_is_null(uu: *const libc::c_void) -> libc::c_int
{
    let res = libc::memcmp(uu, UUID_NULL.as_ptr() as *const libc::c_void, SIZE_OF_UUID_T);
    return !res;    
}

#[no_mangle]
pub unsafe extern "C" fn uuid_parse(in_arg: *const libc::c_char, uu: *mut libc::c_uchar) -> libc::c_int
{
    let mut n = 0;
    //let format = CString::new("%2hhx%2hhx%2hhx%2hhx-%2hhx%2hhx-%2hhx%2hhx-%2hhx%2hhx-%2hhx%2hhx%2hhx%2hhx%2hhx%2hhx%n").unwrap();
    let format = br"%2hhx%2hhx%2hhx%2hhx-%2hhx%2hhx-%2hhx%2hhx-%2hhx%2hhx-%2hhx%2hhx%2hhx%2hhx%2hhx%2hhx%n";

    libc::sscanf(in_arg,
        format.as_ptr() as *const i8,
        uu.offset(0), uu.offset(1),
        uu.offset(2), uu.offset(3),
        uu.offset(4), uu.offset(5),
        uu.offset(6), uu.offset(7),
        uu.offset(8), uu.offset(9),
        uu.offset(10), uu.offset(11),
        uu.offset(12), uu.offset(13),
        uu.offset(14), uu.offset(15),
        &mut n);

    if n != 36 || *in_arg.offset(n) != 0 {
        return -1;
    } else {
        return 0;
    }
}

#[no_mangle]
pub unsafe extern "C" fn uuid_unparse_lower(uu: *const libc::c_uchar, out_arg: *mut libc::c_char)
{
    //let format = CString::new("%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x").unwrap();
    let format = br"%02X%02X%02X%02X-%02X%02X-%02X%02X-%02X%02X-%02X%02X%02X%02X%02X%02X";

    libc::snprintf(out_arg,
        SIZE_OF_UUID_STRING_T,
        format.as_ptr() as *const i8,
        *uu.offset(0) as c_uint, *uu.offset(1) as c_uint,
        *uu.offset(2) as c_uint, *uu.offset(3) as c_uint,
        *uu.offset(4) as c_uint, *uu.offset(5) as c_uint,
        *uu.offset(6) as c_uint, *uu.offset(7) as c_uint,
        *uu.offset(8) as c_uint, *uu.offset(9) as c_uint,
        *uu.offset(10) as c_uint, *uu.offset(11) as c_uint,
        *uu.offset(12) as c_uint, *uu.offset(13) as c_uint,
        *uu.offset(14) as c_uint, *uu.offset(15) as c_uint);
}

#[no_mangle]
pub unsafe extern "C" fn uuid_unparse_upper(uu: *const libc::c_uchar , out_arg: *mut libc::c_char)
{
    //let format = CString::new("%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x").unwrap();
    let format = br"%02X%02X%02X%02X-%02X%02X-%02X%02X-%02X%02X-%02X%02X%02X%02X%02X%02X";

    let res = libc::snprintf(out_arg,
        SIZE_OF_UUID_STRING_T,
        format.as_ptr() as *const i8,
        *uu.offset(0) as c_uint, *uu.offset(1) as c_uint,
        *uu.offset(2) as c_uint, *uu.offset(3) as c_uint,
        *uu.offset(4) as c_uint, *uu.offset(5) as c_uint,
        *uu.offset(6) as c_uint, *uu.offset(7) as c_uint,
        *uu.offset(8) as c_uint, *uu.offset(9) as c_uint,
        *uu.offset(10) as c_uint, *uu.offset(11) as c_uint,
        *uu.offset(12) as c_uint, *uu.offset(13) as c_uint,
        *uu.offset(14) as c_uint, *uu.offset(15) as c_uint);
    assert!(res>0, "encoding error");
}

#[no_mangle]
pub unsafe extern "C" fn uuid_unparse(uu: *const libc::c_uchar , out_arg: *mut libc::c_char)
{
    uuid_unparse_upper(uu, out_arg);
}
