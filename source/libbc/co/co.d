module libbc.co.co;

import libbc.co.aco;

Co g_coMainCo;
CoStack g_coGlobalStack;

struct CoStack
{
    @disable this(this){}

    @nogc nothrow:

    package aco_share_stack_t* handle;

    this(size_t size)
    {
        this.handle = aco_share_stack_new(size);
    }
    
    ~this()
    {
        if(this.handle)
        {
            aco_share_stack_destroy(this.handle);
            this.handle = null;
        }
    }
}

struct Co
{
    @disable this(this){}

    @nogc nothrow:

    package aco_t* handle;

    package this(void*)
    {
        this.handle = aco_create(null, null, 0, null, null);
    }

    static void threadInit()
    {
        g_coMainCo = Co(null);
        g_coGlobalStack = CoStack(4096*8);
    }

    static void yield()
    {
        aco_yield();
    }

    static void exit()
    {
        aco_exit();
    }

    static Co* current()
    {
        static Co co;
        co.handle = aco_co();
        return &co;
    }

    this(Co* owner, CoStack* stack, size_t saveStack, aco_cofuncp_t entry, void* userData)
    {
        assert(owner, "Please pass an owner.");
        assert(owner.handle, "Owner has a null handle. If the owner is g_coMainCo, please make sure Co.threadInit() has been called first on this thread.");
        assert(stack, "Please pass a stack.");
        assert(stack.handle, "Stack has a null handle.");
        assert(entry, "Please pass an entrypoint.");
        this.handle = aco_create(owner.handle, stack.handle, saveStack, entry, userData);
    }

    this(size_t saveStack, aco_cofuncp_t entry, void* userData = null)
    {
        this(&g_coMainCo, &g_coGlobalStack, saveStack, entry, userData);
    }

    void resume()
    {
        assert(this.handle, "I'm null");
        aco_resume(this.handle);
    }

    ref void* arg()
    {
        assert(this.handle, "I'm null");
        return this.handle.arg;
    }

    T* argAs(T)()
    {
        return cast(T*)this.arg();
    }

    bool done()
    {
        return this.handle.is_end != 0;
    }
    
    ~this()
    {
        if(this.handle)
        {
            aco_destroy(this.handle);
            this.handle = null;
        }
    }
}