#include <mach-o/dyld.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

//Keep only executable code in Contents/MacOS; .NET resolves its runtime assets
//beside the actual host in Contents/Resources/runtime. exec preserves arguments.
int main(int argc, char **argv)
{
    (void)argc;
    char executable[PATH_MAX], resolved[PATH_MAX], target[PATH_MAX];
    uint32_t capacity = sizeof(executable);
    if (_NSGetExecutablePath(executable, &capacity) != 0 || !realpath(executable, resolved)) {
        perror("Cannot locate HoianViewer bundle");
        return 1;
    }
    char *separator = strrchr(resolved, '/');
    if (!separator)
        return 1;
    *separator = '\0';
    int length = snprintf(target, sizeof(target), "%s/../Resources/runtime/PlayerViewer", resolved);
    if (length < 0 || (size_t)length >= sizeof(target))
        return 1;
    argv[0] = target;
    execv(target, argv);
    perror("Cannot start HoianViewer");
    return 1;
}
