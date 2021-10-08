import core.internal.entrypoint, libbc.co.co, libbc.co.task;

mixin _d_cmain;

extern(C) int _Dmain(char[][])
{
    Co.threadInit();

    Task ta, tb;
    ta = Task(&a);
    tb = Task(&b);
    ta.resume();
    tb.resume();
    ta.resume();
    tb.resume();
    assert(ta.hasError);

    return 0;
}

import core.stdc.stdio;

nothrow @nogc:

void a()
{
    printf("a1\n");
    Co.yield();
    printf("a2\n");
    Task.exitRaise("errr");
}

void b()
{
    printf("b1\n");
    Co.yield();
    printf("b2\n");
    Co.exit();
}