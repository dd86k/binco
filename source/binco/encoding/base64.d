module binco.encoding.base64;

import std.base64;
public import binco.wrapper;

/+private alias BaseT = const(ubyte)[];

/// 
alias Base64Encoder = EncodingWrapper!(Base64.Encoder!(BaseT));/*
/// 
alias Base64Decoder = EncodingWrapper!(Base64.Decoder!(BaseT));
/// 
alias Base64URLNoPaddingEncoder = EncodingWrapper!(Base64URLNoPadding.Encoder!(BaseT));
/// 
alias Base64URLNoPaddingDecoder = EncodingWrapper!(Base64URLNoPadding.Decoder!(BaseT));
/// 
alias Base64URLEncoder = EncodingWrapper!(Base64URL.Encoder!(BaseT));
/// 
alias Base64URLDecoder = EncodingWrapper!(Base64URL.Decoder!(BaseT));

unittest
{
    ubyte[] data = cast(ubyte[])"Hello, I am test\r\n";
    
    Encoding encoder = new Base64Encoder(data);
    
    foreach (encoded; encoder)
    {
        assert(encoded == "SGVsbG8gSSBhbSB0ZXN0IA0K");
    }
}

unittest
{
    ubyte[] encoded = cast(ubyte[])"SGVsbG8gSSBhbSB0ZXN0IA0K";
    
    Encoding decoder = new Base64Decoder(encoded);
    
    foreach (data; decoder)
    {
        assert(data == "Hello, I am test\r\n");
    }
}+/