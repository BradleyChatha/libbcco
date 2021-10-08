module libbc.co.ptr;

import std.traits : fullyQualifiedName;

import core.stdc.stdlib;

private enum TypeIdOf(alias T) = fullyQualifiedName!T;

struct CoContextPtr
{
    private void*  _ptr;
    private string _id;

    @disable this(this){}

    @nogc nothrow:

    this(T)(auto ref T value)
    {
        this._alloc = alloc;
        this.setByForce(value);
    }

    ~this()
    {
        if(this._ptr !is null)
        {
            free(this._ptr);
            this._ptr = null;
        }
    }

    @trusted // Because ptrUnsafeAs is not @safe. It technically *is* @safe by itself due to the safety checks, but the user can use it to perform @system behaviour.
    private void accessImpl(ValueT, FuncT)(FuncT func)
    {
        assert(!this.isNull, "This TypedPtr is null.");
        func(*this.ptrUnsafeAs!ValueT);
    }

    void access(T)(scope void delegate(T) @nogc nothrow func)
    {
        static assert(false, "Please mark the parameter as `scope ref`");
    }

    void access(T)(scope void function(T) @nogc nothrow func)
    {
        static assert(false, "Please mark the parameter as `scope ref`");
    }

    void access(T)(scope void delegate(scope ref T) @nogc nothrow func) { this.accessImpl(func); }
    void access(T)(scope void function(scope ref T) @nogc nothrow func) { this.accessImpl(func); }
    @safe
    void access(T)(scope void delegate(scope ref T) @nogc @safe nothrow func) { this.accessImpl(func); }
    @safe
    void access(T)(scope void function(scope ref T) @nogc @safe nothrow func) { this.accessImpl(func); }

    @safe
    bool contains(alias T)() const
    {
        assert(!this.isNull, "This TypedPtr is null.");
        return this._id == TypeIdOf!T;
    }

    void setByForce(T)(auto ref T value)
    {
        static if(is(T == struct))
            static assert(__traits(isPOD, T), "Type `"~T.stringof~"` must be a POD struct.");

        if(this._ptr is null)
        {
            this._ptr = calloc(T.sizeof, 1);
            if(this._ptr is null)
                assert(false, "Memory allocation failed.");
        }
        else if(this._id != TypeIdOf!value)
        {
            free(this._ptr);
            this._ptr = null;
            this.setByForce(value);
            return;
        }

        move(value, *(cast(T*)this._ptr));
        this._id = TypeIdOf!T;
    }

    void opAssign(T)(auto ref T value)
    {
        assert(
            this.isNull || this._id == TypeIdOf!T, 
            "opAssign cannot store a value of a different type from the current value. Use `setByForce` for that."
        );
        this.setByForce(value);
    }

    void opAssign()(typeof(null) n)
    {
        if(!this.isNull)
        {
            this._id = null;
            this._alloc.dispose(this._ptr);
        }
    }

    @property @safe
    bool isNull() const
    {
        return this._ptr is null;
    }

    @property
    inout(void*) ptrUnsafe() inout
    {
        assert(!this.isNull, "This TypedPtr is null.");
        return this._ptr;
    }

    @property
    inout(T)* ptrUnsafeAs(T)() inout
    {
        assert(!this.isNull, "This TypePtr is null.");
        assert(this._id == TypeIdOf!T, "Type mismatch. This TypedPtr does not store `"~T.stringof~"`");
        return cast(inout(T)*)this._ptr;
    }
}