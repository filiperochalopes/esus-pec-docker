<img src="https://github.com/filiperochalopes/e-SUS-PEC/blob/main/assets/img/docker-esus.png" alt="e-SUS PEC em Docker"/>

# e-SUS PEC em Docker

![version](https://img.shields.io/badge/version-5.3.19-green) ![version](https://img.shields.io/badge/version-5.3.22-green)

Estrutura Docker para instalar e atualizar o [e-SUS PEC](https://sisaps.saude.gov.br/esus/) em ambientes de treinamento, produção ou cloud.

## Requisitos

- [Docker Engine](https://docs.docker.com/engine/install/)
- [Docker Compose](https://docs.docker.com/compose/install/)

## 📥 Instalação

Prepare a configuração uma vez:

```sh
cp .env.example .env
```

Revise o `.env` e escolha o modo de instalação. O [`Makefile`](Makefile) chama o [`scripts/build.sh`](scripts/build.sh), que baixa automaticamente a versão mais recente do PEC quando nenhum JAR é informado.

### Treinamento

```sh
make training
```

### Produção

```sh
make production
```

### Banco externo

Configure a conexão PostgreSQL no `.env` e execute:

```sh
make external
```

### Cloud

```sh
cp cloud/.env.example cloud/.env
make cloud
```

No modo cloud, a porta interna `80` é publicada em `HTTP_PORT` e a porta `443` em `HTTPS_PORT`. Em um proxy reverso, use o host Docker e `HTTP_PORT`.

Para usar uma versão específica, informe o arquivo local ou a URL do JAR:

```sh
make training JAR=eSUS-AB-PEC-5.x.x-Linux64.jar
```

Use o mesmo argumento `JAR=<arquivo-ou-url>` com `production`, `external`, `cloud` ou `restore`. Consulte os demais alvos com `make help`.

## Migração de versão

> [!IMPORTANT]
> No Linux, a migração do banco pode ter menos verificações do que no instalador para Windows. Toda atualização deve ser testada previamente em um ambiente que possa ser descartado. Antes de atualizar a produção, gere e valide um backup recuperável para garantir o fallback caso a migração falhe ou apresente incompatibilidades.

Fluxo obrigatório:

1. **Backup:** gere e valide o backup da versão atual.
2. **Atualização:** execute a migração primeiro em um ambiente de teste.
3. **Validação:** confirme a inicialização, os dados e os fluxos críticos do PEC.
4. **Produção:** faça um novo backup e somente então repita a atualização validada.

Para atualizar uma instalação com banco local:

```sh
make update-local
```

Para banco externo, use `make update-external`.

## Restauração de backup

No modo cloud, um backup pode ser restaurado antes da inicialização:

```sh
make restore BACKUP=caminho/arquivo.backup
```

## Documentação

- [Procedimento operacional padrão](docs/POP.md)
- [Base de conhecimento operacional](docs/KNOWLEDGE.md)
- [Opções do pacote Java](docs/pacote-java.md)
- [Problemas conhecidos](docs/problemas-conhecidos.md)
- [Investigação de problemas](docs/investigacao-de-problemas.md)
- [Geração do codebase para análise](docs/codebase.md)

## Patrocínio

Agradecimentos à equipe [NoHarm](https://noharm.ai/) pelo apoio ao projeto.

<div align="center">
  <a href="https://noharm.ai/"><img src="https://github.com/filiperochalopes/e-SUS-PEC/blob/main/assets/img/noharm.svg" width="200" alt="NoHarm"/></a>
  <br/><br/>
  <a href="https://buy.stripe.com/6oEdTgaJx3N17EQ145"><img src="https://img.shields.io/badge/Apoio%20Recorrente-008CDD?style=for-the-badge&logo=stripe&logoColor=white" alt="Apoio recorrente"/></a>
  <a href="https://donate.stripe.com/28oaH48Bp2IX5wI4gg"><img src="https://img.shields.io/badge/Compre_um_caf%C3%A9-FFDD00?style=for-the-badge&logo=buymeacoffee&logoColor=white" alt="Compre um café"/></a>
</div>
