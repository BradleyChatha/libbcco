module libbc.co.task;

import libbc.co.co, libbc.co.ptr;

enum TaskState
{
    uninit,
    running,
    yielded,
    errored,
    done
}

alias TaskFunc = void function() @nogc nothrow;

private struct TaskContext
{
    CoContextPtr  userContext;
    CoContextPtr  taskYieldValue;
    TaskFunc      entryPoint;
    string        error;
    bool          yieldedWithValue;
}

struct Task
{
    private Co             _coroutine;
    private TaskState      _state;
    private TaskContext    _context;

    @disable this(this){}

    @nogc nothrow:

    this(TaskFunc func, size_t saveStack = 4096)
    {
        this(func, null, saveStack);
    }

    this(T)(TaskFunc func, auto ref T context, size_t saveStack = 4096)
    {
        static if(!is(T == typeof(null)))
            this._context.userContext = CoContextPtr(context);

        this._context.entryPoint = func;
        this._coroutine = Co(saveStack, &coroutine, &this._context);
    }

    void opPostMove(ref return scope Task rhs)
    {
        import std.algorithm : move;

        move(rhs._coroutine, this._coroutine);
        move(rhs._context, this._context);
        this._state     = rhs._state;
        if(this._coroutine.arg)
            this._coroutine.arg = &this._context;
    }

    extern(C) private static void coroutine()
    {
        auto ctx = Co.current.argAs!TaskContext();
        assert(ctx !is null, "This was not called during a task. Tasks are a more focused layer placed on top of coroutines.");
        assert(ctx.entryPoint !is null, "No/null entrypoint was given.");
        ctx.entryPoint();
        Co.exit();
    }

    ~this()
    {
        if(this.isValid)
            this.dispose();
    }

    void resume()
    {
        assert(this.isValid, "This task is in an invalid state.");
        assert(!this.hasError, "This task has errored. Used `.error` to see what went wrong.");
        this._state = TaskState.running;
        this._context.yieldedWithValue = false;
        this._coroutine.arg = &this._context;
        this._coroutine.resume();

        if(this._context.error !is null)
            this._state = TaskState.errored;
        else if(!this._coroutine.done)
            this._state = TaskState.yielded;
        else
            this._state = TaskState.done;
    }

    void dispose()
    {
        assert(this.isValid, "This task is in an invalid state.");
        this._state = TaskState.uninit;
        this._coroutine.__xdtor();
    }

    ref T valueAs(alias T)()
    {
        assert(this.hasValue);
        return *this._context.taskYieldValue.ptrUnsafeAs!T;
    }

    @property @safe
    TaskState state() const
    {
        return this._state;
    }

    @property
    bool isValid()
    {
        return this._coroutine != Co.init;
    }

    @property
    string error()
    {
        assert(this.hasError, "This task hasn't errored, there's no reason for this to be called.");
        return this._context.error;
    }

    @property
    bool hasError()
    {
        assert(this.isValid);
        return this._state == TaskState.errored;
    }

    @property
    bool hasYielded()
    {
        assert(this.isValid);
        return this._state == TaskState.yielded;
    }

    @property
    bool hasEnded()
    {
        assert(this.isValid);
        return this._state == TaskState.done || this.hasError;
    }

    @property
    bool hasValue()
    {
        assert(this.isValid);
        return this._state == TaskState.yielded && this._context.yieldedWithValue;
    }

    static void yield()
    {
        Co.yield();
    }

    static void exitRaise(string error)
    {
        auto ctx = Co.current.argAs!TaskContext();
        assert(ctx !is null, "This was not called during a task. Tasks are a more focused layer placed on top of coroutines.");
        ctx.error = error;
        Co.yield();
    }

    static void yieldValue(T)(auto ref T value)
    {
        auto ctx = Co.current.argAs!TaskContext();
        assert(ctx !is null, "This was not called during a task. Tasks are a more focused layer placed on top of coroutines.");
        ctx.taskYieldValue.setByForce(value);
        ctx.yieldedWithValue = true;
        Co.yield();
    }

    static void accessContext(alias T, alias Func)()
    {
        auto ctx = Co.current.argAs!TaskContext();
        assert(ctx !is null, "This was not called during a task. Tasks are a more focused layer placed on top of coroutines.");
        ctx.userContext.access!T((scope ref T value) { Func(value); });
    }
}