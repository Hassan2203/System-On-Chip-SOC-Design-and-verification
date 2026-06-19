#define LED_ADDR ((volatile unsigned int *)0x00002000)

/* Original value was 5, which is visible in simulation but far too fast for real LEDs.
   This larger loop gives a human-visible delay after synthesis to FPGA hardware. */
#define DELAY_COUNT 2000000u

static void led_write(unsigned int pattern)
{
    *LED_ADDR = pattern;
}

static void delay(void)
{
    volatile unsigned int i;
    for (i = 0; i < DELAY_COUNT; i++) {
    }
}

void main(void)
{
    while (1) {
        led_write(0x01);
        delay();
        led_write(0x02);
        delay();
        led_write(0x04);
        delay();
        led_write(0x08);
        delay();
        led_write(0x04);
        delay();
        led_write(0x02);
        delay();
    }
}
