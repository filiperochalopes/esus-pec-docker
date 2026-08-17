# Geração do codebase

O JAR do PEC pode ser decompilado para ajudar a distinguir falhas da aplicação de inconsistências no banco.

No macOS:

```sh
brew install cfr-decompiler
./gen-codebase.sh eSUS-AB-PEC-5.5.22-Linux64.jar
```

Use sempre o JAR exato da versão investigada. O gerador preserva `codebase/KNOWLEDGE.md` fora do diretório durante a limpeza, restaura o arquivo e valida seu SHA-256. A regeneração do codebase não deve alterar esse arquivo.
