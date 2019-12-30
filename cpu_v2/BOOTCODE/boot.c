void    _start(void) __attribute__ (( naked ));
void    set_gpio_dir(unsigned int x);
void    set_gpio_out(unsigned int x);
int     op_div(int x, int y);

void
_start(void)
{
    int x, y, z;

    asm("lui sp, 1");
    set_gpio_dir(1);
    set_gpio_out(1);

    x = -626222723;
    y = 5921;
    z = x / y;

    if (z == -105763)
        set_gpio_out(0);

    while (1)
        ;
}

int
op_div(int x, int y)
{
    return x / y;
}

void
set_gpio_dir(unsigned int x)
{
    asm volatile("csrrw x0, 0x100, %0;" : : "r"(x));
}

void
set_gpio_out(unsigned int x)
{
    asm volatile("csrrw x0, 0x103, %0;" : : "r"(x));
}