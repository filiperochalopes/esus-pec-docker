# KNOWLEDGE.md

Base cumulativa de conhecimento reutilizável sobre o e-SUS-PEC deste repositório.

## CDS profissional

- `CdsProfissionalServiceImpl` resolve `tb_cds_prof` por `hash`, não por busca parcial em `INE`/`CNES`.
- O hash é gerado com `CNS + CBO + CNES + INE` em `CdsEncrypt.generateSHA1CdsProf(...)`.
- `saveProfissional(...)` primeiro tenta `loadProfissional(...)`; se não houver match, persiste um novo `CdsProfissional`.
- `loadUnicaLotacaoHeaderForm(...)` carrega o header do CDS a partir do `co_seq_cds_prof` e faz join com `QProfissionalHistoricoCns` para recuperar `CPF` a partir do `CNS`.

## Ficha de atendimento individual

- A persistência da ficha individual ocorre em `FichaAtendimentoIndividualMasterFormSaveCommand`, que delega a conversão para `AtendIndividualForm2EntityConverter`.
- O conversor salva o profissional principal com `profService.saveProfissional(lotacaoFormPrincipal)` e grava o retorno em `CdsMapaAtendIndividual.cdsProfissionalPrincipal`.
- O atendimento compartilhado só é salvo quando o segundo header tem `CNS` preenchido.
- A leitura da ficha individual usa `profService.loadUnicaLotacaoHeaderForm(cdsProfissionalPrincipal.getId())`, então a exibição do cabeçalho da ficha vem do `co_seq_cds_prof` persistido na própria ficha.
- A listagem de fichas individuais faz join direto com `cdsProfissionalPrincipal` e exibe `CNS`, `CBO`, `CNES` e `INE` desse profissional.
- A transmissão CDS da ficha individual também usa `cdsProfissionalPrincipal` como fonte de `CNES` e `INE`.

## Fluxo de seleção no cabeçalho

- `BaseHeaderFichaCdsPresenterImpl` monta o cabeçalho em cascata: profissional -> CBO -> CNES -> INE.
- O combo de profissional pesquisa por `CPF/CNS` ou por nome, e restringe por município e listas de `CNS` permitidos/excluídos.
- O combo de INE usa `EquipeSelectDtoTypedComboPresenter.hasIneEqualNullInLotacao()`, que consulta `LotacaoService.hasIneEqualNullInLotacao(cbo, profissionalCNS, cnesUnidadeSaude)`.
- `LotacaoServiceImpl.loadLotacoesByProfissionalIne(...)` e `loadUnidadeSaudeIdByProfissionalIdAndIne(...)` filtram por `lotacao.profissional.id + equipe.ine`; não fazem lookup de `tb_cds_prof`.
- `LotacaoServiceImpl.hasIneEqualNullInLotacao(...)` aceita filtros opcionais de `CBO`, `CNS` e `CNES` e só verifica se a lotação tem `equipe.id is null`.

## Listagem e consulta

- A listagem de atendimentos individuais (`FichaAtendimentoIndividualRowItemPagingQuery`) usa o `cdsProfissionalPrincipal` da ficha e filtra por `CNS`, `CBO`, `CNES` e `INE` desse profissional.
- O `ORDER BY` da listagem é por `status`, `data`, `CNES` e `INE`; não há ordenação descendente por `co_seq_cds_prof`.

