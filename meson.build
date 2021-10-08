project('libbcco', ['c', 'd'])

src = [
    'source/libbc/co/package.d',
    'source/libbc/co/co.d',
    'source/libbc/co/aco.d',
    'source/libbc/co/ptr.d',
    'source/libbc/co/task.d',
    'libaco/aco.c',
    'libaco/acosw.S',
]

include = include_directories('source/')

libbcco = static_library('bcco', src, include_directories: include, d_args: ['-betterC'])
libbcco_test = executable('bcco_test', src, 'source/test.d', include_directories: include, d_args: ['-betterC'])

libbcco_dep = declare_dependency(sources: src, include_directories: include)