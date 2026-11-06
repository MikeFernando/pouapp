# Plano de continuidade para o Cursor — Hortifruti

3 de novembro de 2026 • Base: Documentacao_Hortifruti(1).md, versão 1.3

## 1. Resultado da revisão

A documentação recebida relata inspeção do código e identifica uma próxima entrega pequena e útil: persistir a nota da cliente como rascunho. Este plano usa essas informações como estado relatado; o repositório não foi disponibilizado nesta conversa para uma nova auditoria. O Cursor deve confirmar caminhos e comportamentos no código atual antes de editar.

Aproveitar Flutter, flutter_bloc, get_it e sqflite existentes. Não recriar as telas de Gestão, Entregas, nota, edição de item ou frete. Não migrar a aplicação para MobX ou Modular com base em outro projeto.

### Ajustes necessários no planejamento

- A nota em rascunho não é dívida nem saída de estoque. Corrigir a apresentação “Aprovado” para refletir o estado real desse rascunho; não transformar exemplos em vendas confirmadas.
- Há duas representações de venda: o ledger persistente da rua e os itens temporários da nota. Antes de confirmar notas, definir uma origem única para a venda e o saldo. Não somar os dois como se fossem operações diferentes.
- Clientes e catálogo estão em bancos SQLite distintos e rua/fretes em SharedPreferences, conforme o documento. Uma sequência de gravações nesses meios não é uma transação atômica. A confirmação de venda exige uma fronteira transacional comum para nota, saída física, dívida, pagamento opcional e operação pendente.
- Preservar os dados já gravados. A migração não pode inventar itens para vendas antigas do ledger nem descontar estoque retroativamente sem informação suficiente. Usar uma data de corte explícita.
- Existem produtos controlados por caixa. Manter essa unidade para registros existentes; converter caixa em kg só quando houver peso líquido informado. Nunca presumir uma caixa de tomate com peso fixo.
- “Sincronização desde os primeiros fluxos” precisa ser dividida: persistência e identificação das operações localmente primeiro; envio e confirmação remota somente quando houver servidor e contrato. Não exibir “sincronizado” enquanto tudo estiver apenas no aparelho.
- Fretes já persistem. Completar lacunas comprovadas, especialmente datas e cobranças, em vez de reconstruir o módulo.

## 2. Sequência de tarefas

Cada tarefa deve ser uma alteração revisável. O Cursor deve registrar o que encontrou, o que modificou, os testes executados e as limitações. Se parte da tarefa já estiver pronta, verificar e completar somente a lacuna.

### T01 — Persistir a nota como rascunho

**Prioridade:** imediata. **Dependência:** nenhuma nova funcionalidade.

Reaproveitar a tela atual. Criar ou estender modelo de rascunho e itens, repositório, persistência SQLite e estado no padrão existente. Guardar ID da nota, cliente, situação, vencimento opcional, datas e itens. Guardar em cada item referência do produto, nome/apresentação exibida, unidade, quantidade na precisão válida e preço praticado em centavos. Não depender do preço atual do catálogo para reabrir a nota.

Proposta para esta entrega: um rascunho ativo por cliente, retomado ao abrir sua conta. Se o código já tiver vários rascunhos, preservar esse comportamento e identificar qual nota está aberta.

Salvar inclusões e edições de itens imediatamente em transação; não depender apenas de dispose ou evento de fechamento. Exibir falha de gravação sem dizer que salvou. Não mudar o ID da nota em cada edição. Não introduzir confirmação de venda nesta tarefa.

**Critérios de conclusão:**

- Abrir uma cliente real; nova nota começa vazia, sem os cinco itens de demonstração.
- Adicionar produto, editar quantidade/preço e vencimento, sair e reabrir: valores permanecem.
- Encerrar o processo e reabrir: o mesmo rascunho permanece e pode ser editado.
- Rascunho da cliente A não aparece na B.
- Estoque, dívida, vendido e recebido não mudam.
- Total resulta dos itens persistidos; dinheiro em centavos e peso em gramas.
- Instalação existente mantém clientes, catálogo, saldo inicial, rua e fretes.

**Validação:** testes de repositório com reabertura do banco, isolamento por cliente, recálculo e migração; teste de tela para editar/salvar/reabrir. Executar flutter analyze e testes relevantes. Se não houver Flutter no ambiente, declarar que não foram executados, sem simular sucesso.

### T02 — Retirar indicadores fictícios e definir situações

**Dependência:** T01.

Separar “Total desta nota”, “Saldo devedor” e “Rascunho”. Mostrar vendido/recebido somente a partir de lançamentos reais cuja origem esteja clara. Indicadores não implementados usam estado vazio ou “Ainda não disponível”, não zero apresentado como cálculo verdadeiro. Dados de demonstração permanecem explicitamente restritos ao ambiente de demonstração/debug.

**Conclusão:** rascunho não aparece como aprovado, entregue ou pago; dívidas anteriores não são confundidas com o total dos itens. Dashboard não soma números simulados a operações reais.

### T03 — Definir persistência transacional e migrar operação de rua

**Dependência:** T01; concluir antes de T06.

Inspecionar bancos e ledger existentes. Reutilizar banco transacional adequado ou criar banco operacional versionado, garantindo que todos os efeitos de uma venda futura estejam na mesma conexão/transação. IDs de clientes podem ser referências estáveis a cadastro externo; gravações de dinheiro e estoque não podem depender de duas transações independentes.

Migrar os registros de rua com IDs estáveis, controle de importação e verificação de quantidades e totais. Preservar cópia da origem e tornar a migração repetível sem duplicação. Não limpar a origem antes de verificar a importação. Se registro antigo não tiver itens, preservar seu histórico financeiro identificado como legado, sem fabricar movimentação física. Documentar data de corte e política para saldo inicial da dívida sem contá-lo junto com o mesmo histórico.

**Conclusão:** repetir inicialização não duplica registros; falha parcial não troca leitura para dados incompletos; dados antigos permanecem consultáveis; há uma única fonte financeira ativa após migração.

**Validação:** migração de base preenchida, reexecução, falha no meio e comparação de totais por cliente. Não basta testar instalação vazia.

### T04 — Movimentações e carga da Montana

**Dependência:** T03.

Estender saldo inicial existente para transferência, perda e ajuste com motivo, origem, destino, ID de operação e histórico. Implementar carga Depósito → Montana e retorno. Validar saldo dentro da transação. Manter unidades existentes; caixa não vira kg automaticamente.

**Conclusão:** depósito com 100 kg, carga de 40 kg resulta em 60/40. Falha no destino não deixa baixa na origem. Repetir confirmação não transfere duas vezes. Finalizar rota não zera estoque sozinho.

### T05 — Contas a receber e pagamentos

**Dependência:** T03.

Implementar obrigações por venda e vencimento, saldo inicial de dívida identificado, pagamentos parciais e alocação às contas. Crédito por pagamento excedente exige decisão explícita. Não modificar vencimentos antigos ao incluir compra nova. Preservar histórico da rua migrado.

**Conclusão:** saldo inicial de R$ 150 e pagamento de R$ 50 resultam em R$ 100, sem criar venda do dia. Registrar pagamento duas vezes com o mesmo ID tem um único efeito. Conta paga não permanece a receber.

### T06 — Confirmar venda entregue na porta

**Dependências:** T01, T03, T04 e T05.

Na tela existente, confirmar rascunho gerando venda, saída da Montana, dívida e pagamento opcional na mesma transação. A chave da confirmação permanece estável em nova tentativa. Verificar estoque antes de concluir; falha não deixa dívida sem saída física ou vice-versa. Prever registro local de operação pendente para sincronização futura, sem fingir envio remoto.

**Conclusão principal:** cliente deve R$ 150; confirmar 1 kg de alho por R$ 30 fiado resulta em R$ 180 e baixa 1 kg. Receber R$ 50 depois resulta em R$ 130. Vendas do dia aumentam só R$ 30. Fechar/reabrir e tocar duas vezes não duplica.

**Validação:** teste integrado das alterações e rollback por falha induzida, repetição idempotente, estoque insuficiente, pagamento parcial e troca posterior do preço do catálogo.

### T07 — Corrigir venda e registrar devolução

**Dependência:** T06.

Manter edição simples para rascunhos. Para venda entregue, usar correção/estorno rastreável, motivo e vínculo ao original. Diferenciar erro de lançamento de nova compra. Correção física deve representar o que aconteceu: redução de quantidade registrada só devolve estoque quando houver fundamento físico ou correção do movimento original. Não alterar pagamentos anteriores.

**Conclusão:** correção aplica diferença uma vez; nova compra tem data/vencimento próprios; redução de débito já pago exige crédito ou reembolso explícito.

### T08 — Completar clientes do dia e fechamento da rota

**Dependências:** T04 e T06.

Aproveitar visitas existentes; acrescentar seleção múltipla se ausente, ordem manual, motivos entregar/vender/cobrar, ausência e reagendamento. Tocar na cliente abre conta com cliente preenchida. Concluir visita não quita dívida. Disponibilidade usa Montana; retorno e perdas têm movimentos próprios.

**Conclusão:** carga 40 kg − vendas 25 kg − perda 2 kg − retorno 13 kg = zero no veículo. Progresso contabiliza visitas concluídas, independentemente de pagamento.

### T09 — Completar os fretes existentes

**Dependência:** leitura do módulo atual; integração financeira depende de T05/T03.

Verificar cadastro local/ida/volta, objetos, coleta, entrega, preço, vencimento e pagamento parcial. Corrigir seleção de próxima viagem: passada não concluída aparece como pendência. Separar período de contratação, entrega e recebimento nos indicadores.

Adiantamentos ficam ligados ao serviço sem duplicar entrada quando ele for entregue. Frete para cliente de hortifruti pode aparecer na conta consolidada com origem distinta. Integrar/migrar dados persistentes antes de somar ao financeiro comum.

**Conclusão:** geladeira na ida e cama na volta não alteram estoque de verduras. Serviço entregue pode estar a receber. Serviço pago pode ainda aguardar coleta.

### T10 — Compra no Ceasa e recebimento

**Dependências:** T03/T04; integrar contas a pagar em T12.

Fornecedores, viagem, compras, quantidades por apresentação de compra e peso líquido, transporte, recebimento parcial e divergência. Encerrar diferenças explicitamente; fornecedor mantém crédito/débito até solução acordada.

**Conclusão:** compra de 100 kg e aceite de 97 kg gera depósito com 97 kg e diferença de 3 kg explicada. Recebimento repetido não duplica entrada. Produto vendido por kg exige peso real da caixa.

### T11 — Pesagem, apresentações e conservação

**Dependências:** T04 e T10.

Definir granel e pacotes como representações físicas relacionadas. Consumir matéria-prima, criar pacotes, devolver sobra e registrar perda na mesma transação. Rastrear recebimentos de origem e conservar custo. Não contar a sobra duas vezes.

**Conclusão:** 10 kg consumidos = 19 pacotes de 500 g + 500 g de sobra. Unidade pacote não aceita fração indevida. Preço por pacote não é confundido com preço/kg.

### T12 — Despesas, custos e resultado

**Dependências:** T05, T06, T09 e T10; custo de pacotes depende de T11.

Contas a pagar, despesas de viagem/rota, pagamentos e rateio. Separar custo incorporado ao estoque de despesa operacional. Em combustível compartilhado, soma das atribuições deve ser 100%. Tratar custo provisório até fechar viagem/divergências. Diferenciar lucro, saldo devedor e caixa.

**Conclusão:** R$ 100 de despesa compartilhada vira R$ 60 compra + R$ 40 frete, sem duplicação. Quitar fornecedor não cria segunda despesa. Receber dívida antiga não aumenta vendas atuais.

### T13 — Servidor, sincronização e recuperação

**Dependência:** contrato de servidor definido e operações locais transacionais.

Definir API e persistência no servidor com ID idempotente. Implementar fila local durável; envio com repetição; estados pendente/enviando/erro/confirmado; autenticação real quando servidor existir; retenção das operações na expiração da sessão. Operações dependentes devem sincronizar em ordem válida e conflitos precisam ser visíveis.

O plano inicial considera um aparelho operador. Liberar vários aparelhos só após política de concorrência de estoque e finanças. Não usar a última escrita para sobrescrever saldo.

**Conclusão:** servidor aceita e resposta se perde; reenvio retorna mesma confirmação, sem segunda venda/pagamento. Processo morto preserva fila. “Salvo no aparelho” é distinto de “Confirmado no servidor”.

### T14 — Importação, backup e piloto real

**Dependências:** fluxos a usar no piloto concluídos.

Preparar exportação/backup antes de usar com dados reais; provar restauração em ambiente separado. Importar clientes com prévia, relatório e tratamento de duplicidade. Entrada de dívidas antigas tem data de corte e não gera nova receita. Fazer piloto de uma rota comparando o app com o controle atual.

**Conclusão:** cliente, dívida, estoque e pagamentos sobrevivem à restauração; reimportar não duplica; divergências do piloto são resolvidas antes de abandonar o controle anterior.

## 3. Prioridade prática

Entregar T01 primeiro e revisar o resultado. Em seguida, estabelecer T03 para não construir novas operações em armazenamento fragmentado. O primeiro fluxo completo de rua é T04 → T05 → T06. T02 melhora a clareza dos dados e T09 pode corrigir datas sem depender do fluxo completo. Compras e pesagem entram depois desse primeiro ciclo, conforme prioridade expressa na versão 1.3.

Esta ordem permite testar a venda com estoque inicial já existente sem exigir construir todo o ERP antes. Não significa que compras ou fretes estejam fora do produto.

## 4. Prompt pronto — executar apenas T01

Copie o texto abaixo no Cursor com a documentação versão 1.3 disponível no repositório.

```text
Continue o aplicativo Flutter de hortifruti existente em mobile/.

Leia AGENTS.md e as instruções do repositório, a documentação de negócio versão 1.3 e o código relacionado. Execute somente a persistência da nota da cliente como RASCUNHO. As telas já existem: preserve layout e navegação, alterando apenas estados/rótulos necessários para representar rascunho e erros reais.

Contexto relatado pela documentação, a confirmar no código:
- clientes e catálogo usam SQLite, em bancos distintos;
- operação da rua e fretes usam SharedPreferences;
- catálogo já persiste produtos, unidades, preço em centavos, mínimo e saldo inicial por local;
- a nota da cliente e os cinco itens de exemplo vivem apenas em memória;
- projeto usa flutter_bloc, get_it e sqflite.
Não trate esses pontos como auditoria atual: confirme os arquivos e comportamentos antes de editar.

Objetivo: abrir cliente → adicionar/editar itens → salvar → recalcular → sair → encerrar processo → reabrir e recuperar o mesmo rascunho.

1. Localize a rota /customers/{id}, a tela da nota, os painéis de edição e inclusão, os modelos/repositórios e a infraestrutura SQLite. Identifique as convenções existentes e testes. Não recrie módulos prontos nem introduza outra biblioteca de estado.
2. Implemente nota em rascunho com ID estável e vínculo ao cliente. Proposta desta entrega: um rascunho ativo por cliente; se já houver suporte a múltiplos, preserve-o.
3. Persista itens com produto, nome/apresentação, unidade, quantidade precisa e preço praticado em centavos; registre vencimento opcional e datas. Peso deve respeitar gramas inteiras; itens de unidade inteira não aceitam frações. Não converter caixa em kg sem peso informado.
4. Ao abrir cliente sem rascunho, mostre lista vazia. Não migre os cinco itens fictícios para notas reais. Mantenha produtos/cadastros legítimos e dados existentes.
5. Salve inclusões e alterações no momento da ação, em transação. Reabra a mesma nota, sem depender só de estado da tela ou dispose. Se a gravação falhar, mantenha a edição recuperável e mostre falha sem indicar sucesso.
6. Recalcule o total a partir dos itens persistidos, com regra única de arredondamento em centavos. Mudança futura do preço no catálogo não altera itens antigos. Identifique “Total desta nota” e “Rascunho”; não apresente o rascunho como aprovado, entregue ou pago.
7. Esta tarefa NÃO confirma venda, NÃO baixa estoque, NÃO gera dívida, NÃO registra pagamento, NÃO muda visitas e NÃO implementa servidor. Preserve ledger da rua e fretes. Não mostre sincronização inexistente.
8. Versione o schema e preserve instalação existente. Não apague bancos nem SharedPreferences para fazer migração passar. Não faça refatoração ampla ou migração da rua neste passo.
9. Teste persistência após fechar/reabrir banco, isolamento de duas clientes, edição de preço/quantidade, total correto, migração e ausência de efeitos financeiros/estoque. Inclua um teste de tela significativo para editar/salvar/reabrir conforme infraestrutura existente. Execute flutter analyze e testes pertinentes; informe impedimentos reais se não puder executá-los.
10. Atualize a documentação de status com evidências da entrega e deixe explícito que confirmação de venda/baixa/dívida são tarefas futuras.

Antes de implementar, apresente brevemente o diagnóstico com arquivos reais e prossiga nesta tarefa. Ao concluir, informe o que mudou, verificações executadas, limitações e um roteiro manual para testar. Não execute as demais etapas do plano nesta alteração.
```

## 5. Como avaliar a entrega do Cursor

Aceitar T01 somente quando o rascunho sobreviver ao encerramento real do processo, a cliente B não herdar itens de A e nenhum saldo físico/financeiro mudar. Um print correto ou hot reload não comprova persistência.

Depois disso, solicitar um relatório dos arquivos e testes da entrega antes de iniciar T03. Se o Cursor informar que já implementou confirmação de venda ou migrou todos os módulos nesta tarefa, revisar o escopo e separar alterações antes de continuar.
