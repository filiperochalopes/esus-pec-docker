# Identidade, acessos e credenciais no codebase 5.5.22

Investigação estática do JAR 5.5.22 decompilado. Nenhum conteúdo do banco foi
consultado.

## Cadeia de identidade assistencial

O modelo vigente confirma:

1. `tb_usuario.co_seq_usuario`;
2. `tb_prof.co_usuario`, mapeado por `Profissional.usuario`;
3. `tb_ator_papel.co_prof`, mapeado por `AtorPapel.owner`;
4. `tb_lotacao.co_ator_papel`, chave compartilhada com a classe-base
   `AtorPapel`.

`Lotacao` usa herança JPA `JOINED` e
`@PrimaryKeyJoinColumn(name="CO_ATOR_PAPEL")`. Portanto, sua PK também é FK
para `tb_ator_papel.co_seq_ator_papel`.

`tb_usuario.co_ator` aparece no metamodelo SQL legado, mas não existe no modelo
JPA `Usuario` nem participa do fluxo atual de autenticação encontrado. Seu
destino, constraint e uso residual devem ser confirmados somente no schema.

## Papéis administrativos

- **Instalador:** `CriarInstalador.execute` cria um
  `AdministradorGeral`, com `no_tipo_ator_papel=ADMINISTRADOR_GERAL`, ativo e
  com instalação concluída. Não existe `TipoAtorPapel.INSTALADOR` nem subtabela
  `tb_instalador`.
- **Administrador geral:** herança compartilhada entre `tb_ator_papel` e
  `tb_adm_geral`, usando `co_ator_papel`. `CriarAdministradorGeral.execute`
  persiste o papel e vincula todos os perfis ativos cujo `tipoPerfil` é
  `ADMINISTRADOR_GERAL`.
- **Administrador municipal:** herança compartilhada entre `tb_ator_papel` e
  `tb_adm_municipal`, usando `co_ator_papel`.
  `MunicipioResponsavelInsert.execute` liga profissional e município, ativa o
  papel, registra `dt_adicao` e atribui o perfil padrão
  `ADMINISTRADOR_MUNICIPAL` por `ComputePerfis`.

Assim, o perfil adicional é parte explícita dos fluxos de administrador geral
e municipal. Para o instalador inicial, o método `CriarInstalador` isolado não
persiste perfis; o orquestrador de instalação precisa ser respeitado.

## Ocupação versus autorização

- Ocupação: `tb_lotacao` contém profissional, unidade, equipe opcional e CBO.
- Autorização: `rl_ator_papel_perfil` tem PK composta
  `(co_ator_papel, co_perfil)` e associa qualquer papel a `tb_perfil`.
- A lotação é simultaneamente um papel, mas CBO não substitui o vínculo de
  perfil.

## Perfis criados pela importação CNES

`LotacaoCnesPersister.persistPerfis` seleciona perfis padrão pelo código
CBO 2002 e pelo grupo da unidade:

- CEO;
- UBS indígena, com possível perfil adicional para edição de cidadão aldeado;
- atenção domiciliar quando a lotação pertence a equipe AD;
- grupo UBS/padrão nos demais casos.

Os IDs vêm dos caches populados por consultas equivalentes a
`PerfilService.getPerfisPadraoByCodigoCbo`. Somente perfis ainda ausentes são
persistidos por `AddPerfisLotacao` em `rl_ator_papel_perfil`.

Logo, não há uma lista universal “médico/enfermeiro”: o conjunto concreto
depende de `rl_perfil_cbo_padrao`, município, grupo da unidade e CBO. Seus IDs
e nomes devem ser resolvidos pelos códigos naturais na instalação-alvo.

## Criação de usuário e senha

`UsuarioService.create(cpf)` chama `UsuarioCreateCommand.create(cpf, null)`.
O usuário inicial recebe:

- `ds_login=cpf`;
- `ds_senha=NULL`;
- `st_termo_uso=true`;
- `st_bloqueado=false`;
- `st_forcar_troca_senha=true`;
- `st_notificacao_novidades=true`;
- `st_termo_teleinterconsulta=false`;
- tentativas de acesso inicializadas em zero pelo modelo.

No código 5.5.22, `UsuarioAceitarTermosUso.execute` muda
`st_termo_uso` para `false`; portanto não se deve interpretar `1` como
“termo já aceito” pelo nome isolado da coluna.

Para senha definitiva, `UsuarioService.redefinirSenha`:

1. registra auditoria de troca de senha;
2. revoga refresh tokens;
3. apaga token de redefinição;
4. zera tentativas de acesso;
5. desbloqueia o usuário;
6. gera o hash e chama `UsuarioSenhaUpdate.setPassword`.

`setPassword` altera:

- `ds_senha` para o hash;
- `st_forcar_troca_senha=false`;
- `dt_ultima_atualizacao_senha=Instant.now()`.

`definirSenhaProvisoria` tem semântica diferente: ao final força nova troca,
zera a data de atualização, zera tentativas e desbloqueia. Não serve como
senha final do laboratório.

O hash é
`sha256:64000:32:<salt-base64>:<hash-base64>`, com salt aleatório de 24 bytes,
64.000 iterações e PBKDF2-HMAC-SHA-256. A constante pública
`PBKDF2_ALGORITHM=PBKDF2WithHmacSHA1` não descreve a estratégia escolhida:
`STRATEGY` é `sha256` e resolve para `PBKDF2WithHmacSHA256`.

SQL direto pode reproduzir os três campos centrais da senha, mas não reproduz
integralmente auditoria, revogação de tokens e limpeza do fluxo de recuperação.

## Estratégia para o gerador demo

Estratégia recomendada: **serviços da aplicação**.

1. importar profissional, lotação e perfis pelo fluxo CNES;
2. criar papéis administrativos pelos comandos próprios;
3. atribuir perfis administrativos pelos comandos próprios;
4. definir a senha final por `UsuarioService.redefinirSenha`;
5. tratar o termo de uso conforme o fluxo oficial;
6. somente então gravar CPF/login, senha sintética, papéis, perfis e lotações
   em `demo_credentials.txt`.

Um modo híbrido pode ser mantido como fallback versionado, mas precisa declarar
que não produz os efeitos de auditoria/tokens do serviço.

## Lacunas exclusivamente de schema

- FK e finalidade atual de `tb_usuario.co_ator`;
- uniques/checks/defaults físicos de login, CPF, usuário-profissional e
  subtabelas de papel;
- triggers das tabelas envolvidas;
- ações `ON DELETE`/`ON UPDATE`;
- códigos naturais concretos dos perfis padrão na instalação 5.5.22.

Essas lacunas estão isoladas no Prompt 02b revisado.
