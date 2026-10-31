#include <windows.h>
#include <stdio.h>
#include <d3dcompiler.h>
int main(int argc, char **argv) {
    FILE *f = fopen(argv[1], "rb"); fseek(f, 0, SEEK_END); long n = ftell(f); fseek(f, 0, SEEK_SET);
    char *b = malloc(n); fread(b, 1, n, f); fclose(f);
    ID3DBlob *t = NULL;
    HRESULT hr = D3DDisassemble(b, n, 0, NULL, &t);
    if (FAILED(hr)) { printf("disassemble failed 0x%08lx\n", (unsigned long)hr); return 1; }
    printf("%s\n", (char *)t->lpVtbl->GetBufferPointer(t));
    return 0;
}
