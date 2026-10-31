// tiny HLSL compiler front-end: hlslc <file.hlsl> <entry> <profile> <out.bin>
#include <windows.h>
#include <stdio.h>
#include <d3dcompiler.h>
int main(int argc, char **argv) {
    if (argc < 5) { printf("usage: hlslc file entry profile out\n"); return 2; }
    FILE *f = fopen(argv[1], "rb"); if (!f) { printf("cannot open %s\n", argv[1]); return 2; }
    fseek(f, 0, SEEK_END); long n = ftell(f); fseek(f, 0, SEEK_SET);
    char *src = malloc(n + 1); fread(src, 1, n, f); src[n] = 0; fclose(f);
    ID3DBlob *code = NULL, *err = NULL;
    HRESULT hr = D3DCompile(src, n, argv[1], NULL, NULL, argv[2], argv[3], D3DCOMPILE_OPTIMIZATION_LEVEL3, 0, &code, &err);
    if (err) printf("%.*s\n", (int)err->lpVtbl->GetBufferSize(err), (char *)err->lpVtbl->GetBufferPointer(err));
    if (FAILED(hr)) { printf("compile failed 0x%08lx\n", (unsigned long)hr); return 1; }
    FILE *o = fopen(argv[4], "wb");
    fwrite(code->lpVtbl->GetBufferPointer(code), 1, code->lpVtbl->GetBufferSize(code), o); fclose(o);
    printf("ok %u bytes\n", (unsigned)code->lpVtbl->GetBufferSize(code));
    return 0;
}
