# Procedimento Operacional Padrão para Instalação, Transferência e Atualização do e-SUS PEC

Para migração do serviço PEC APS para outra infraestrutura, é necessário alguns recursos para garantir o total funcionamento do prontuário e suas integrações com serviços externos com segurança.

## 1. Realizando o Backup (Dump) do Banco de Dados PostgreSQL

### Linux
1. Execute o comando para criar um dump em formato **plain**:
   ```bash
   pg_dump -U <usuario> -d <nome_do_banco> -F p > backup.sql
   ```

2. Compacte o arquivo:
   - **ZIP**:
     ```bash
     zip backup.zip backup.sql
     ```
   - **TAR.GZ**:
     ```bash
     tar -czvf backup.tar.gz backup.sql
     ```

### Windows

A primeira opção é [realizar o backup pela interface da instalação](https://youtu.be/D_ATuuZ7ehg?feature=shared&t=44). A outra opção é pelo terminal:

1. No PowerShell, crie o dump em formato **plain**:

Segue um exemplo, lembre-se de trocar os paths de acordo com o seu ambiente:

```powershell
# Para verificar a senha de seu banco de dados
cat 'C:\Program Files\e-SUS\webserver\config\credenciais.txt'

C:\Users\PC\Desktop> & 'C:\Program Files\e-SUS\database\postgresql-9.6.13-4-windows-x64\bin\pg_dump.exe' -Fc -U postgres -p 5433 -d esus -v -f backup.dump
# O sistema irá peduir a senha
```

1. Compacte o arquivo:
   - **ZIP**:
     ```powershell
     Compress-Archive -Path backup.sql -DestinationPath backup.zip
     ```

## 2. Envio do Backup para Google Drive (ou Alternativas)
1. Faça o upload do arquivo compactado para o Google Drive (ou outro serviço de nuvem, como Dropbox ou OneDrive).
2. Gere o link de compartilhamento e envie-o ao destinatário.

## 3. Envio de credenciais do instalador

Para dar maior celeridade ao processo é importante, nesse primeiro momento que tenhamos o usuário e senha do Instalador da aplicação PEC do município que foi transferida, essa senha pode ser alterada depois do processo pelo próprio instalador para manter a sua seguraça e autonomia das configurações.

Com isso visamos habilitar os serviços:
- [CADSUS](https://saps-ms.github.io/Manual-eSUS_APS/docs/PEC/PEC_03_adm_conf/#3111-cadsus) - Para ser possível acessar pacientes direto do da Central de Cadastros de Cidadãos do SUS
- [Agendamento Online](https://saps-ms.github.io/Manual-eSUS_APS/docs/PEC/PEC_03_adm_conf/#3113-agenda-online) - Com essa funcionalidade o Paciente terá também informações sobre seu agendamento no aplicativo [Meu SUS Digital](https://meususdigital.saude.gov.br/)
- [Teleinterconsulta/atendimento](https://saps-ms.github.io/Manual-eSUS_APS/docs/PEC/PEC_03_adm_conf/#3113-teleinterconsulta) - Possibilidade de consultas de seguimento e interconsultas online pela plataforma do PEC
- [Prescrição eletrônica](https://saps-ms.github.io/Manual-eSUS_APS/docs/PEC/PEC_03_adm_conf/#3113-prescri%C3%A7%C3%A3o-digital)
- [Hórus](https://saps-ms.github.io/Manual-eSUS_APS/docs/PEC/PEC_03_adm_conf/#3112-h%C3%B3rus) - [Mais informações](https://bvsms.saude.gov.br/bvs/folder/horus_folder.pdf)

## 4. Cadastro/Envio das Chaves/Certificados Necessárias

### 4.1 *Contra-Chave* para Instalação do PEC e Ativação do agendamento Online

Essa chave é necessária para envio e instalação da contra-chave do PEC, siga o manual oficial (Seção 2.4.4): [Criando Contra-Chave](https://saps-ms.github.io/Manual-eSUS_APS/docs/PEC/PEC_02_instalacao/#244-gerar-contra-chave-e-ativar-agendamento-online).

### 4.2 *Certificado Digital* para integração com RNDS

Siga as instruções para garantir a configuração correta para acessar a RNDS conforme descrito no manual (Seção 3.12): [Configuração de Acesso à RNDS](https://saps-ms.github.io/Manual-eSUS_APS/docs/PEC/PEC_03_adm_conf/#312-acessando-a-rnds-por-meio-do-pec).

Com isso você terá um certificado digital do Município capaz de reconhecer a autenticidade da identidade, é necessário que, após o processo o certificado (arquivo *.pfx ou *.p12) seja instalado na pasta adequada da instalação. Para isso solicitamos que nos envie o arquivo por email.

### 4.3 Certificados HTTPS

A partir do PEC 5.3 essa funcionalidade foi [automatizada](https://saps-ms.github.io/Manual-eSUS_APS/docs/Apoio%20a%20Implanta%C3%A7%C3%A3o/HTTPS_Automatizado/) utilizando o serviço certmgr já incluso no pacote *.jar da instalação. 

## 5. Padrão de Ofícios

Algumas etapas do proceso necessitam de envio de ofícios aos órgãos competentes, para liberação de algumas funcionalidades, são elas:

### 5.1 Solicitação de Domínio GOV.br

Necessário para realizar login por meio de seu [usuário GOV.br](https://saps-ms.github.io/Manual-eSUS_APS/docs/Apoio%20a%20Implanta%C3%A7%C3%A3o/HTTPS_Automatizado/#requisitos-obrigat%C3%B3rios). É possível que outras funcionalidades exijam esse requisito, por isso, pode ser que vale à pena fazer. Verifique qual o órgão competente no seu estado para criação de domínios (por exemplo, na Bahia é a [PRODEB](https://www.prodeb.ba.gov.br/page/registro-de-dominio))

Segue um exemplo de email que pode ser enviado:

```txt
Ao [Nome do Órgão Competente],

Prezados(as),

Solicitamos a criação do domínio [nome do domínio solicitado] para uso oficial nas atividades de saúde pública do município de [Nome do Município], em conformidade com as diretrizes do Ministério da Saúde e com foco na implantação do Prontuário Eletrônico do Cidadão (PEC e-SUS APS).

Dados para registro:
- Nome da Instituição: [Razão Social da Prefeitura].
- CNPJ: [CNPJ da Prefeitura].
- Responsável pelo domínio: [Nome do Responsável].
- Contato: [E-mail e telefone do responsável].

Dados do servidor de hospedagem:
- IPv4: [IPv4 da instalação]
* Para redirecionamento à esse IP não é necessário Name Server (NS), apenas que o subdomínio tenha um apontamento do tipo A para o IPv4.

Justificativa: Este domínio será utilizado para suportar as funcionalidades do PEC, como teleconsultas, prescrições digitais e agendamentos online, além de garantir a integração com serviços como RNDS e CADSUS.

Agradecemos pela atenção e aguardamos retorno.

Atenciosamente,
[Nome do Responsável pela Solicitação]
```

Após isso realizar uma solicitação por e-mail para cadastro das credenciais na aplicação `/opt/eSUS/webserver/config/application.properties` adicionando:

```txt
bridge.security.oauth2.client.registration.govbr.client-id=ClientID
bridge.security.oauth2.client.registration.govbr.client-secret=ClientSecret
```

### 5.2 Solicitação para ativação da Prescrição Digital

A solicitação de ativação deverá ser feita através de um ticket de suporte que deverá ser criado pela equipe responsável pela instalação na Plataforma de suporte https://esusaps.freshdesk.com segundo padrão abaixo:

```txt
Prezados(as),

Solicitamos a ativação da funcionalidade de prescrição digital na instalação do PEC do município de [Nome do Município], conforme as orientações do manual oficial.

Dados para ativação:
- URL da instalação: [URL do PEC configurado].
- Dados do responsável pela instalação: [Nome, telefone e e-mail].
- Município já utiliza certificado digital integrado ao PEC: Sim.

Aguardamos as credenciais necessárias para habilitar a funcionalidade no perfil do administrador da instalação.

Atenciosamente,
[Nome do Solicitante]
```

Aguarde retorno com usuário e senha para a instalação.

## 6. Checklist

O checklist abaixo resume as atividades necessárias para garantir o funcionamento completo do PEC após instalação, transferência ou atualização. Use os seguintes símbolos para indicar o status:

- ✅ **Concluído**: Atividade já realizada com sucesso.
- ⏸️ **Pendente (Prioridade Baixa)**: Atividade em andamento ou não urgente no momento.
- 🚩 **Pendente (Prioridade Alta)**: Atividade essencial que requer atenção imediata.

### **Checklist**

- ✅ **Instalação do certificado digital HTTPS** (necessário para vídeo chamadas, teleconsultas).
- ✅ **Instalação da contra-chave** (disponibilidade de agendamento online e vinculação PEC no e-Gestor).
- ⏸️ **Migrar serviço de DNS para Gov.br** (No momento iremos manter o domínio noharm.ai - Pendente ofício para PRODEB).
- ✅ **Habilitar funcionalidades do perfil do instalador**.
- ✅ **Configuração de SMTP para envio de emails**.
- 🚩 **Instalação de certificado digital do município A1 ou do certificado feito pelo e-Gestor**.  
  [Referência: Seção 3.12 - Configuração de Acesso à RNDS](https://saps-ms.github.io/Manual-eSUS_APS/docs/PEC/PEC_03_adm_conf/#312-acessando-a-rnds-por-meio-do-pec).
- 🚩 **Solicitação (ofício) para liberar emissão de prescrições digitais na instalação**.  
  [Referência: Seção 3.1.1.3 - Prescrição Digital](https://saps-ms.github.io/Manual-eSUS_APS/docs/PEC/PEC_03_adm_conf/#3113-prescri%C3%A7%C3%A3o-digital).
