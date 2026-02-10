module binco.wrapper;

import std.range.primitives : ElementType, isForwardRange, isInputRange;

interface Encoding
{
public:
    nothrow @trusted ubyte[] front();
    @trusted void popFront();
    @trusted bool empty();
}

class EncodingWrapper(T) if (isInputRange!T) : Encoding
{
    T core;
    
    this(ubyte[] range)
    {
        core = T(range);
    }
    
    @trusted
    bool empty() const
    {
        return core.empty;
    }
    
    nothrow @trusted
    ubyte[] front()
    {
        return core.front();
    }
    
    @trusted
    void popFront()
    {
        core.popFront();
    }
}
