# Problemas conhecidos

## Compatibilidade de versões

- Desde o PEC 5.3, o certificado SSL é autogerenciado e o Java utilizado é o 17 LTS. A imagem atual não é destinada a versões anteriores.
- Java 8 com OpenSSL 3.x pode apresentar incompatibilidade com chaves PKCS12. Instalações legadas podem exigir chaves JKS e uma imagem compatível.
- As versões 4.2.7 e 4.2.8 não foram validadas com sucesso neste projeto.
- A versão 4.2.8 apresentou falhas de autorização no formulário de cadastro via GraphQL.
- A versão 5.0.8 apresentou falhas intermitentes no carregamento de exames e atendimentos; o comportamento deixou de ocorrer após a atualização para 5.0.14.

## Recursos do servidor

Uma finalização inesperada com a mensagem `Killed` geralmente indica falta de memória. Verifique o consumo e os limites do container e do host antes de procurar uma falha da aplicação.

Antes de atualizar uma instalação, consulte as [notas oficiais da versão](https://saps-ms.github.io/Manual-eSUS_APS/).
