#define VGA_MEMORY 0xb8000
#define VGA_LEN 25*80
#define FILL 0x9f

int
kmain ()
{
  char msg[] = "sapatinhos ";
  char* vga = (char *)VGA_MEMORY;
  int i = -1;
 
  while (++i != VGA_LEN)
    {
      vga[2*i] = msg[i % 11];
      vga[2*i + 1] = FILL; 
    }
    
    while(1){} 
}
