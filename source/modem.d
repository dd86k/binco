module modem;

import binco.wrapper;
import std.base64;

enum EncodingType
{
    base16,
    //base32,
    //base32z,
    //base36,
    //base58,
    base64,         // Base64
    base64u,        // Base64 URL no-padding, RFC 4648 and 7515 
    base64up,       // Base64 URL with padding
    //ascii85,
    //base91,
    //base1024,     // https://github.com/shea256/emojicoding
    //uuencoding,
    //xxencoding,
    //bson,
}
enum NoEncoding = cast(EncodingType)-1;

class Modem
{
    Encoding encoder;
    EncodingType encoding;
    Base64.Decoder!(ubyte[]) thingy;
    
    this(ubyte[] data, EncodingType type, bool decoding)
    {
        /+final switch (type) with (EncodingType) {
        case base64:
            thingy = Base64.decoder(data);
            break;
        case base64u:
            //thingy = Base64URLNoPadding.decoder(data);
            break;
        case base64up:
            //thingy = Base64URL.decoder(data);
            break;
        }+/
    }
    
    enum bool empty = false;
    
    ubyte[] front()
    {
        return null;
    }
    
    ubyte[] popFront()
    {
        return null;
    }
}