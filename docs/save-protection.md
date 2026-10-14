# Proteção dos saves

Os slots passam a usar `user://save_slot_N.protected.json`. O JSON externo contém
somente `format`, `version`, `iv`, `payload` e `hmac`; dinheiro, upgrades, estoque,
identidade e scripts ficam dentro do payload criptografado.

`systems/SaveCodec.gd` usa AES-256-CBC com padding PKCS#7 e um IV aleatório de
16 bytes por gravação. HMAC-SHA-256 usa uma chave independente e autentica o
identificador do formato, versão, IV e ciphertext. A verificação ocorre antes
da descriptografia, comparação em tempo constante. As APIs são nativas do Godot;
nenhuma biblioteca adicional é necessária. A versão do envelope é independente
da versão 5 dos dados de progresso.

O SaveManager prepara e verifica um arquivo temporário antes de substituir o
slot. Falhas de autenticação não aplicam progresso nem mantêm o slot ativo para
autosave. O menu permanece na seleção de saves. Importações inválidas não
substituem arquivos nem alteram os sistemas do jogo.

## Compatibilidade

Na inicialização, slots antigos `save_slot_N.json` são migrados quando não existe
um arquivo protegido correspondente. O antigo `save.json` continua migrando para
o slot 1 quando nenhum slot protegido existe. Os arquivos originais são mantidos
para recuperação; excluir explicitamente um slot também exclui seu arquivo
legado correspondente, evitando que ele reapareça na inicialização seguinte.

O carregamento de um caminho protegido nunca aceita JSON aberto. A importação
no navegador aceita somente envelopes protegidos. Para transferir um save antigo,
abra o jogo atualizado no navegador/dispositivo de origem e exporte o slot migrado.
O download continua sendo JSON, com o sufixo `.protected.json`.

## Limites

Esta é uma barreira contra edição casual. As chaves estão no cliente e podem ser
extraídas; cliente modificado, edição em memória e restauração de saves legítimos
antigos continuam possíveis. A migração não prova a legitimidade de dados antigos.
Quem remover os arquivos protegidos pode criar arquivos legados para acionar a
migração novamente. Não utilizar estes saves como prova de resultados competitivos
ou notas; isso exige validação externa ao cliente.

Não rotacionar/remover as chaves atuais sem implementar leitura das versões
anteriores: isso tornaria os saves existentes ilegíveis. O envelope externo tem
limite de 1 MiB, inclusive na leitura local.

## Verificação

`res://tests/save_security_test.tscn` cobre round-trip com Unicode, IV aleatório,
campos adulterados, JSON aberto, truncamento, limite de tamanho, importação entre
slots, preservação de arquivo/runtime na falha, bloqueio de autosave após rejeição,
migração local e prioridade do formato protegido. Os testes preservam os arquivos
de slots presentes antes da execução.

A execução headless valida as APIs nativas e o codec compartilhado; o fluxo real
de seleção/download de arquivo via JavaScriptBridge deve ser conferido no export web.
