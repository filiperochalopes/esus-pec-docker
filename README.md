<img src="https://github.com/filiperochalopes/e-SUS-PEC/blob/main/assets/img/docker-esus.png" alt="e-SUS PEC em Docker"/>

# e-SUS PEC em Docker

![version](https://img.shields.io/badge/version-5.3.19-green) ![version](https://img.shields.io/badge/version-5.3.22-green)

Estrutura Docker para instalar e atualizar o [e-SUS PEC](https://sisaps.saude.gov.br/esus/) em ambientes de treinamento, produção ou cloud.

## Requisitos

- [Docker Engine](https://docs.docker.com/engine/install/)
- [Docker Compose](https://docs.docker.com/compose/install/)

## 📥 Instalação

O [`build.sh`](build.sh) baixa automaticamente a versão mais recente do PEC e inicia o ambiente.

### Treinamento

```sh
cp .env.development .env
sh build.sh
```

### Produção

```sh
cp .env.example .env
sh build.sh -p
```

### Cloud

```sh
cp cloud/.env.example cloud/.env
sh build.sh -C -p
```

No modo cloud, a porta interna `80` é publicada em `HTTP_PORT` e a porta `443` em `HTTPS_PORT`. Em um proxy reverso, use o host Docker e `HTTP_PORT`.

Para usar uma versão específica, informe o arquivo local ou a URL do JAR:

```sh
sh build.sh -f eSUS-AB-PEC-5.x.x-Linux64.jar
```

Consulte todas as opções com `sh build.sh --help`.

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
sh update.sh compose.local-db.yml
```

Para banco externo, use `compose.external-db.yml`.

## Restauração de backup

No modo cloud, um backup pode ser restaurado antes da inicialização:

```sh
sh build.sh -C -p -r caminho/arquivo.backup
```

## Documentação

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
