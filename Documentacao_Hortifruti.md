# Documentação do aplicativo de hortifruti

Versão 1.11 • 4 de novembro de 2026 • Proposta alinhada ao código do aplicativo móvel

## 1. Objetivo e situação atual

Administrar a compra de frutas e verduras no Ceasa de Curitiba, o transporte até Apiaí, o recebimento no depósito, a pesagem, a carga da Montana, as entregas e vendas às clientes e o recebimento à vista ou fiado.

A operação tem mais de 400 clientes cadastradas e vendas com prazo de aproximadamente 30 dias. As telas de Gestão, Entregas, nota da cliente, edição de item e fretes existem no aplicativo Flutter em `mobile/`. O código foi inspecionado em 3 de novembro de 2026. Parte dessas telas grava dados no aparelho; outra parte ainda mostra valores simulados ou mantidos só na memória da tela.

Esta documentação separa o que o código faz hoje das propostas ainda não implementadas. Prazos, limites e comportamentos sugeridos devem ser validados durante o desenvolvimento. Não se pressupõe integração com outro projeto ou com o aplicativo de conferência de doca.

### O que o código faz hoje

| Área | Onde está | O que permanece ao fechar o aplicativo |
|---|---|---|
| Clientes, endereços e contatos | SQLite `pouapp_customers.db` | Cadastro, busca e edição. No modo debug há clientes de demonstração; release não os insere |
| Visitas, vendas da rua e pagamentos da rua | SQLite `pouapp_catalog.db`, depois da migração verificada. A cópia anterior permanece em SharedPreferences e não recebe gravação nova | Identificadores, visitas, valores, datas existentes e marca de demonstração. Venda antiga não ganha data, produto, baixa nem dívida |
| Fretes | SharedPreferences | Agenda, trecho e situações. A integração financeira com a operação continua posterior |
| Modo Entregas ou Gestão | SharedPreferences | A última escolha da tela inicial |
| Produtos, mínimo, saldo e movimentações | SQLite `pouapp_catalog.db`, versão 9 | Nome, unidade, preço em centavos, mínimo por local, saldo inicial e movimentações confirmadas de carga, retorno, perda, conferência e venda |
| Locais | Código, não tabela | Em transporte, Depósito e Montana |
| Nota exibida na cliente | SQLite `pouapp_catalog.db`, rascunho e entrega confirmada, na mesma conexão da operação. A cópia anterior permanece em `pouapp_customers.db` | O rascunho guarda itens, preços e vencimento. “Confirmar entrega” grava venda, saída da Montana, dívida e pagamento opcional na mesma transação. Depois disso a nota fica consultável e a edição direta fica bloqueada |
| Conta da cliente | SQLite `pouapp_catalog.db`, tabelas de dívida, recebimento, estorno e cobrança preparada | Saldo inicial, recebimento em dinheiro ou Pix, alocação, troco, crédito explícito e estorno. A cobrança preparada não entra no financeiro |
| Chave Pix do negócio | SQLite `pouapp_catalog.db`, perfil do negócio | Tipo, chave e nome do recebedor. A cobrança reutiliza esses dados. Não há QR Code nem código Pix Copia e Cola |
| Compras, recebimentos do Ceasa, equipe e contas a pagar | Ainda não há lançamento próprio | O início mostra “Ainda não disponível”. Não entram no vendido nem no recebido |
| Vendido, recebido e a receber do início | Operação na base ativa, sem demonstração e sem somar a origem antiga | Vendido registrado reúne as vendas gravadas. Venda antiga entra sem data; venda nova grava o dia do fato e o instante do registro. Recebido registrado soma cada pagamento da rua e cada recebimento confirmado da conta uma única vez. A receber é a soma dos saldos positivos das contas. Cobrança preparada, troco e rascunho não entram |

Peso de produto por quilograma é gravado em gramas inteiras e mostrado em kg. Unidade, maço e caixa usam quantidade inteira. Dinheiro do catálogo usa centavos. O saldo de um produto é a soma dos lançamentos daquele produto, separada por local. Estoque baixo significa saldo abaixo do mínimo daquele local; saldo igual ao mínimo não é baixo. Produto inativo não aparece como estoque baixo.

O saldo inicial continua sendo um lançamento por produto e local. A chave estável é `opening:{produto}:{local}`. Além dele, o catálogo grava carga, retorno, perda e conferência. Cada confirmação tem um identificador estável, criado quando o rascunho abre, e não muda se a gravação falhar ou for repetida. Repetir o mesmo identificador não movimenta de novo. O histórico confirmado não é apagado nem reescrito.

Carregar a Montana transfere do Depósito para a Montana. Retornar ao depósito faz o caminho inverso. A saída e a entrada são gravadas na mesma transação: se a entrada falha, a saída também é desfeita. Vários produtos entram na mesma confirmação; se um não puder sair, nenhum sai e o rascunho da carga permanece. A quantidade tem de ser maior que zero e caber no saldo do local de origem. O saldo não fica negativo.

Perda pede quantidade, local e motivo. Conferência pede a quantidade física contada e o motivo; o sistema grava a diferença em relação ao saldo. Quilograma continua em gramas. Unidade, maço e caixa continuam inteiros. Caixa não vira quilograma. Nenhuma dessas movimentações cria venda, dívida, receita ou despesa. Encerrar visita ou rota não zera a carga.

No modo debug, o depósito começa com alho 500 kg, cebola 600 kg e batata 800 kg. Essas três ficam acima do mínimo. A banana nanica entra com 40 dúzias, porque é vendida na dúzia e não por quilograma. Também entram tomate 14 cx, alface 40 un, laranja 22 kg, mamão 8 kg e limão 6 kg. Laranja, mamão e limão ficam abaixo do mínimo e aparecem em “Você pode precisar”. Uma instalação que já tinha a banana de demonstração em quilograma, ainda sem outra movimentação, passa a contá-la em dúzia. Alho, cebola e batata entram sem apagar os produtos anteriores. Release começa sem esses produtos. A pesagem e a embalagem em pacotes de 1 kg e de 500 g ainda não são lançadas nesta etapa. “Ver produto” abre o saldo por local e o histórico, com acesso à operação que originou cada lançamento depois do saldo inicial. Ver o produto não muda a quantidade.

A Disponibilidade da rua mostra a carga atual da Montana e abre “Carregar Montana” e “Retornar ao depósito”. No estoque, as ações são “Carregar Montana”, “Retornar ao depósito”, “Registrar perda” e “Conferir estoque”. Na Gestão, Pesagem abre a tela de pesar e embalar. Na batata ela mostra o palete e as embalagens de 2,5 kg. Confirmar a pesagem não tira peso do depósito e não carrega a Montana; essa carga segue na próxima etapa. O detalhe de Vendas da Gestão continua sem gravar. A autenticação é simulada e não representa usuário da operação. A fila de sincronização fica no aparelho. Sem servidor, nenhum registro é marcado como enviado. O reconhecimento de voz pode precisar de internet; o restante da entrega continua no aparelho.

Na conta da cliente, “Receber pagamento” grava dinheiro ou Pix já conferido. O valor recebido é o dinheiro que fica. Se a cliente entrega mais e recebe troco, o troco é calculado à parte e não vira crédito nem recebido. O valor acima da dívida escolhida só vira crédito se essa opção for marcada. Antes de confirmar, a tela mostra saldo anterior, valor recebido e saldo restante. Pagamento parcial é permitido. A data começa no dia de hoje. A observação é opcional. Repetir a mesma confirmação não aloca de novo.

“Registrar saldo inicial” abre uma dívida identificada. Ela não é venda do dia e não mexe no estoque. Repetir o mesmo identificador não muda o vencimento já gravado. Nova compra, quando a confirmação de venda existir, não reescreve vencimento antigo.

“Enviar cobrança Pix” prepara uma mensagem para uma cliente. Dá para cobrar o saldo restante de uma dívida, o saldo total em aberto ou outro valor positivo até esse saldo. O rascunho da nota não entra como dívida confirmada. Várias dívidas com vencimentos diferentes são identificadas como saldo em aberto, sem uma data única inventada. A prévia mostra destinatário, telefone, valor, chave e mensagem. Abrir o WhatsApp usa o telefone cadastrado, com país e DDD, e a mensagem preenchida. A pessoa toca em Enviar no WhatsApp. Voltar ao aplicativo não significa que a mensagem foi enviada nem que a cliente pagou. O histórico, quando existe, fica como “Cobrança preparada” ou “WhatsApp aberto”. Na lista do dia, a cobrança abre uma conversa de cada vez, só com os dados daquela cliente. Não há envio para grupo.

A chave Pix fica em Ajustes, na Gestão. O tipo pode ser CPF/CNPJ, telefone, e-mail ou aleatória. Sem telefone ou sem chave, a cobrança oferece corrigir o cadastro. Se o WhatsApp não abrir, a prévia permanece e a mensagem e a chave podem ser copiadas. Enviar a cobrança ou a chave não registra pagamento. O retorno do WhatsApp e a existência de comprovante também não confirmam recebimento.

O estorno preserva o meio, dinheiro ou Pix, e reabre a dívida. O recebimento estornado sai do recebido. A receber do início e as receitas em aberto do extrato usam a mesma soma: só saldo positivo, e o crédito de uma cliente não paga a dívida de outra enquanto ninguém escolher usá-lo. Zero real aparece como R$ 0,00. O saldo da visita na lista do dia continua o cálculo da rua, inclusive a demonstração.

“Confirmar entrega”, na nota em rascunho, revisa cliente, produtos, quantidades, total, saldo anterior, vencimento da compra, pagamento opcional e saldo previsto. A compra pode ficar fiada, ser paga por inteiro ou em parte, em dinheiro ou Pix. O troco e o crédito seguem as regras já usadas no recebimento. O Pix continua manual. O pagamento mostra, antes de gravar, quanto vai para esta compra e quanto vai para dívidas anteriores. Dívida antiga só entra se estiver marcada.

A confirmação usa o identificador da nota. Toque repetido, reabertura ou nova tentativa recuperam a mesma venda. A nota entregue mostra “Entregue” e não aceita edição direta. “Nova compra” abre outro rascunho, com outro identificador. A venda grava o dia da entrega e o instante do registro. Vendas antigas da rua permanecem sem data inventada e sem baixa retroativa de estoque. “Nova venda” na visita abre essa nota, em vez de criar uma segunda venda no ledger da rua.

O estoque é conferido dentro da transação, somando os itens que usam o mesmo produto. Quilograma sai em gramas. Unidade, maço e caixa saem em contagem inteira. Produto inativo, sem saldo ou sem vínculo com o estoque impede a confirmação. Pacote ou caixa de um produto controlado em quilogramas exige conversão cadastrada; essa conversão ainda não existe, então a operação incompatível é recusada. Uma falha no meio desfaz venda, saída, dívida e pagamento. A venda confirmada entra uma vez no vendido. O pagamento entra uma vez no recebido. A cobrança Pix seguinte usa o saldo restante da nota ou da conta. Nota quitada não aparece como cobrança pendente. Abrir o WhatsApp não registra pagamento. A confirmação fica marcada para sincronização futura, sem aparecer como enviada.

### Resultado esperado

Responder com confiança: quanto comprei, onde está a mercadoria, quanto perdi, quanto vendi, quanto recebi, quem me deve e quanto custou operar.

## 2. Decisões iniciais propostas

| Tema | Proposta para a primeira versão |
|---|---|
| Contextos de uso | Modo Entregas e Modo Gestão |
| Locais de estoque | Em transporte, Depósito e Montana |
| Atendimento | Encomenda antecipada e venda na porta |
| Fiado | Vencimento por venda, sugerido em 30 dias após a entrega |
| Cliente atrasada | Aviso e confirmação; bloqueio configurável posteriormente |
| Estoque negativo | Impedir movimentação; oferecer conferência e ajuste justificado |
| Operação sem internet | Vendas, entregas, recebimentos e consulta da carga disponíveis localmente |
| Usuários | Proprietário inicialmente; preparar identificação do responsável pelas operações |
| Custos | Custo por recebimento, preservado durante transferências e embalagem |
| Moeda e peso | Reais em centavos; peso em gramas inteiras e exibição em kg |

Pontos ainda não confirmados: frequência das viagens, quantidade de aparelhos simultâneos, existência de funcionários, origem dos 400 cadastros e política de preços por cliente. Não condicionar o primeiro fluxo completo a essas respostas: usar um operador e um aparelho como escopo inicial.

## 3. Evolução da tela inicial

A referência apresenta seletor Entregas/Gestão, localização Apiaí, atalhos Receber/Pesagem/Ajuste/Vendas, sugestões de estoque baixo, resumo financeiro e navegação inferior.

### Modo Gestão

| Elemento | Comportamento previsto |
|---|---|
| Receber | Abrir compras em transporte e iniciar conferência no depósito |
| Pesagem | Selecionar produto a granel e montar pacotes |
| Ajuste | Registrar contagem física, diferença e motivo |
| Vendas | Consultar vendas e iniciar venda quando aplicável |
| Você pode precisar | Listar produtos abaixo do estoque mínimo configurado |
| Empresa hoje | Mostrar vendas entregues e pagamentos recebidos na data, separadamente |
| Estoque e recebimento | Mostrar compras aguardando recebimento e acesso ao estoque por local |
| Botão + | Abrir ações nomeadas: compra, venda, despesa e recebimento de pagamento |

O + do produto em estoque baixo deve abrir a inclusão em uma lista de compras, sem aumentar estoque. Enquanto essa lista não existe, o código usa a ação “Ver produto”. “Receber mercadoria” e “Receber pagamento” devem ter nomes distintos. Receber, Ajuste e Vendas da Gestão ainda não gravam. Pesagem mostra a separação da batata e ainda não grava o depósito. A aba Estoque abre o cadastro e o saldo persistidos.

### Modo Entregas — operação rápida na rua

O usuário confirmou dois modos: Entregas e Gestão. Entregas reúne atendimento das clientes selecionadas para o dia, novas compras adicionadas à conta, recebimentos de pagamentos e fretes com a Montana. Gestão concentra compras, depósito, pesagem, ajustes e acompanhamento financeiro.

A nova referência mostra uma lista “Recebimentos do dia”, progresso 2 de 4, botão Nova venda e atalhos Frete, Clientes, Recebimento e Disponibilidade. Esses elementos precisam ter os seguintes significados:

| Elemento | Comportamento proposto |
|---|---|
| Lista principal | “Clientes do dia”: pessoas selecionadas para entregar, vender ou cobrar |
| Selecionar clientes | Busca nos mais de 400 cadastros, seleção múltipla e ordem manual |
| Linha da cliente | Nome, saldo devedor identificado, motivo da visita e situação do atendimento |
| Toque na cliente | Abre sua conta com ações Adicionar compra, Receber pagamento e Ver histórico |
| Progresso | Atendidas / selecionadas; não representa dívidas quitadas |
| Nova venda | Escolher cliente e produtos; se aberta dentro da conta, cliente já preenchida |
| Frete | Serviços locais, ida a Curitiba e volta para Apiaí |
| Clientes | Cadastro geral com busca; adicionar à lista do dia |
| Recebimento | Renomear para “Receber pagamento”; selecionar cliente e valor |
| Disponibilidade | Carga atual da Montana, com “Carregar Montana” e “Retornar ao depósito” |
| Botão + | Adicionar cliente ao dia, nova venda, receber pagamento ou novo frete |

R$ 0,00 não significa que a cliente não tem encomenda ou que a visita está concluída. Mostrar “Sem dívida” quando esse for o sentido. Não riscar o nome como único sinal de conclusão: mostrar situação textual e permitir reabrir o atendimento.

Selecionar uma cliente para o dia não cria venda, reserva ou pagamento. Confirmar uma venda ou pagamento também não deve concluir a visita automaticamente. A mesma cliente pode comprar, pagar parte da dívida e continuar devendo. Motivos da visita podem coexistir: entregar, vender e cobrar. Registrar ausência e reagendamento sem movimentar estoque ou dinheiro.

### Conta da cliente — “editar a nota”

A experiência deve parecer um caderno simples: saldo em destaque, últimas compras, pagamentos e três ações visíveis: **Adicionar compra**, **Receber pagamento** e **Histórico**. “Nota” significa aqui a conta comercial da cliente, sem pressupor emissão de nota fiscal.

Fluxo principal: tocar na cliente da lista → Adicionar compra → buscar alho → selecionar 1 kg → conferir R$ 30 → confirmar entrega fiada. A cliente já vem selecionada, o local é a Montana e o preço vem do cadastro, permitindo alteração explícita. Exibir saldo anterior, compra atual e saldo previsto antes de confirmar.

| Exemplo confirmado pelo usuário | Valor |
|---|---:|
| Saldo anterior | R$ 150,00 |
| Nova compra: alho, 1 kg | R$ 30,00 |
| Saldo após confirmar a compra fiada | R$ 180,00 |
| Se depois pagar R$ 50,00 | R$ 130,00 |

Não pedir para redigitar a dívida nem reabrir uma venda antiga para adicionar a compra de hoje. Cada compra é um lançamento novo, apresentado na mesma conta, preservando data, itens e vencimento próprios. A dívida de R$ 150 mantém seus vencimentos; os R$ 30 recebem o prazo combinado para a nova compra.

Para vendas entregues na porta, uma única confirmação deve gravar venda, saída da Montana e conta a receber. Rascunho não movimenta nada. Se a compra for paga na hora, registrar também o pagamento e mostrar seu efeito no saldo, distinguindo pagamento da compra atual de quitação de dívida anterior. Permitir pagamento parcial na mesma confirmação.

Priorizar busca rápida, produtos recentes/favoritos, quantidades comuns como 500 g e 1 kg, teclado numérico e uma revisão compacta. Não obrigar a passar por telas de gestão. Manter rascunho ao sair e voltar; confirmação repetida não duplica o lançamento. “Desfazer” uma confirmação deve gerar estorno rastreável.

### Navegação proposta por modo

Entregas: Início, Entregas, Financeiro e Clientes, conforme a referência; Frete permanece como atalho visível. Gestão: Início, Compras, Estoque e Financeiro; Clientes continua acessível pelo menu. Os dois modos compartilham cadastros, contas e histórico. Trocar de modo não altera saldos, não encerra rota e não descarta rascunhos.

### Estados obrigatórios

Toda tela de dados deve prever carregamento, lista vazia com próxima ação, erro com tentativa novamente e dados locais sem conexão. Mostrar data da última atualização e operações aguardando sincronização. Valores fictícios devem ser substituídos por zero ou estado vazio quando não houver registros.

A localização Apiaí pode ser uma configuração do negócio; GPS não é necessário para o primeiro fluxo.

## 4. Fluxo operacional principal

1. Criar viagem ao Ceasa e registrar despesas.
2. Registrar compras e fornecedores; informar pagamento ou obrigação a pagar.
3. Marcar mercadorias como em transporte.
4. Conferir o peso líquido recebido no depósito e registrar diferenças.
5. Separar e pesar pacotes, registrando sobras e perdas.
6. Preparar rota e transferir carga do depósito para a Montana.
7. Entregar encomendas ou registrar vendas na porta.
8. Confirmar entrega e registrar pagamento integral, parcial ou fiado.
9. Retornar sobras, registrar perdas e conferir carga.
10. Fechar rota e acompanhar contas a receber e a pagar.

## 5. Regras de negócio

### RB-01 — Produtos e unidades

Produto deve ter nome, categoria, unidade-base, situação ativa/inativa, preço de venda e estoque mínimo opcional por local. Permitir kg, unidade e maço. Produto com histórico não pode ser excluído: deve ser inativado.

Uma caixa é uma apresentação de compra. Para produto controlado por peso, registrar número de caixas, peso bruto, tara quando conhecida e peso líquido real. Não presumir que caixas tenham sempre o mesmo peso. Conversão de unidade para kg exige informação real e não pode ser inventada pelo sistema.

Apresentações como alho 500 g e alho 1 kg vinculam-se ao produto-base. O sistema deve distinguir apresentação e quantidade física para não contar os mesmos quilos duas vezes.

### RB-02 — Compras e recebimento

Compra tem fornecedor, viagem opcional, itens, valores, descontos e condição de pagamento. Quantidade comprada, recebida e rejeitada são campos distintos. Recebimentos parciais não podem duplicar entrada.

A confirmação de recebimento movimenta somente a quantidade aceita para o depósito. Diferença exige motivo. Exemplo: 100 kg comprados e 97 kg aceitos geram 97 kg disponíveis e 3 kg de divergência a resolver.

A diferença física não reduz automaticamente a dívida com fornecedor. Registrar se haverá crédito, abatimento, reposição ou perda assumida. Se os 3 kg foram perdidos durante transporte, registrar a baixa correspondente; se nunca foram enviados, registrar a divergência de fornecimento. O saldo em transporte deve ser encerrado explicitamente, sem desaparecer.

### RB-03 — Movimentações e disponibilidade

Saldo deve resultar de movimentos confirmados: entrada, transferência, transformação, saída por entrega, perda, devolução e ajuste. Cada movimento registra identificador único, produto/apresentação, quantidade, local, origem da operação, data e responsável.

Transferência entre locais não gera receita nem despesa. Saída da origem e entrada no destino são uma operação atômica. Não permitir apenas metade da transferência.

Disponível para novos pedidos = saldo físico − reservas ativas. Estoque reservado continua fisicamente no local. Ao carregar uma encomenda, transferir também sua reserva para a Montana, evitando reserva duplicada.

### RB-04 — Pesagem e embalagem

Transformar 10 kg de alho em 20 pacotes de 500 g consome 10 kg a granel e cria as apresentações correspondentes em uma única confirmação. Somente depois da confirmação os saldos mudam.

Conservação obrigatória: peso consumido = peso embalado + sobra devolvida ao granel + perda declarada. A mesma sobra não pode ficar no granel e em um pacote. Embalagens podem compor custo, sem exigir controle físico de sacolas no primeiro ciclo.

Preço fixo por pacote e venda por peso são formas diferentes de precificação. A venda deve guardar qual delas foi usada. Em peso variável, calcular valor pelo peso real e arredondar o total do item em centavos com regra única.

### RB-05 — Conservação e perdas

Identificar recebimentos internos pela compra e data de entrada, mesmo sem lote do fornecedor. Permitir validade informada quando existir e previsão de consumo quando útil; previsão não deve aparecer como validade oficial.

Sugerir saída dos produtos com validade mais próxima; na ausência de validade, dos mais antigos. Perda exige quantidade, local e motivo. Produto impróprio não pode voltar ao estoque disponível.

### RB-06 — Carga e rota

Carga identifica veículo, data, operador e produtos. Conferir disponibilidade antes de confirmar. Carregar é transferir do depósito para a Montana.

Rota organiza clientes por ordem manual inicialmente. Endereço, referência e observações devem estar acessíveis. Otimização automática de trajeto fica para depois.

Fechamento: carga inicial + entradas − entregas − perdas − retornos ao depósito = saldo final da Montana. Retornar ao depósito exige movimentação; finalizar a rota não zera estoque automaticamente. Diferença de contagem exige ajuste justificado.

### RB-07 — Pedidos e entregas

Pedido antecipado pode reservar estoque. Venda na porta usa a carga disponível. Rascunho não altera estoque ou financeiro. A confirmação da entrega registra a saída física e o valor devido, uma única vez.

Permitir atendimento parcial com confirmação dos itens efetivamente entregues. Itens não entregues ficam pendentes ou são cancelados por decisão explícita. Registrar preços e descontos no momento da venda; mudar o cadastro depois não muda vendas antigas.

Cancelamento anterior à entrega libera reserva. Após entrega, corrigir por devolução/estorno rastreável. Não apagar histórico confirmado.

### RB-08 — Clientes e fiado

Cliente tem nome, telefone, endereço, referência, observações, situação e política de crédito opcional. Usar identificador interno; telefone não deve ser a chave única obrigatória, pois pode ser compartilhado.

Cada entrega fiada gera sua própria conta a receber, com vencimento sugerido em 30 dias corridos. Registrar a data combinada. Nova compra não prorroga automaticamente dívida anterior.

Pagamento pode quitar parcialmente uma ou várias contas. Sugerir as mais antigas e permitir revisão antes de confirmar. Vincular cada parcela do pagamento à dívida correspondente. Pagamento a mais exige confirmação para registrar crédito da cliente, sem receita fictícia.

Mostrar total em aberto, vencido, a vencer e crédito separadamente. Não incluir saldo já quitado. Juros e multas ficam fora do início e não devem ser aplicados automaticamente.

### RB-09 — Dinheiro e despesas

Separar venda, conta a receber e pagamento. Uma venda de R$ 80 fiado gera R$ 80 vendidos, R$ 80 a receber e R$ 0 recebido naquele momento. Receber dívida antiga gera entrada de dinheiro, sem nova venda.

Despesa tem categoria, valor, data, vencimento, situação e viagem/rota opcional. Compra a prazo gera conta a pagar; pagamento quita a obrigação. Uma compra não pode virar despesa duplicada quando paga.

Registrar dinheiro, Pix e cartão como meios distintos. Na primeira versão, registrar manualmente; integração bancária e confirmação automática de Pix ficam para depois. Venda no cartão e dinheiro efetivamente liquidado devem ser distinguíveis se cartões forem usados.

Retiradas do proprietário devem ter categoria própria e não entrar como custo da mercadoria.

### RB-10 — Custos e resultado

Proposta inicial: manter custo por recebimento e consumir os recebimentos na ordem de saída definida. Transformações herdam o custo consumido; transferências preservam esse custo.

Distribuir despesas diretamente ligadas à aquisição pelo valor de compra dos itens elegíveis, com critério registrado. Exemplo: compra A de R$ 200 e B de R$ 300 com frete de R$ 100 acrescenta R$ 40 a A e R$ 60 a B. Rateio por peso pode ser configurado futuramente, sem misturar kg e unidades.

Custo final do recebimento depende da resolução das divergências. Enquanto houver despesas ou divergências abertas, marcar custo e margem como provisórios. Ao fechar a viagem, concluir o custo e ajustar os efeitos nos produtos já vendidos de forma rastreável.

Resultado gerencial = vendas líquidas entregues − custo dos produtos vendidos − custo das perdas − despesas operacionais não incorporadas ao estoque. Despesas incorporadas ao estoque não são descontadas novamente. Fluxo de caixa considera recebimentos e pagamentos por data e não equivale a lucro.

### RB-11 — Correções e histórico

Confirmações devem ser transacionais. Toque repetido e reenvio não podem duplicar operações. Alteração confirmada exige registro de estorno/correção com motivo e vínculo ao original. Manter data do fato e data de registro.

Devolução deve registrar condição física e solução financeira: redução de dívida, crédito ou devolução do dinheiro. A solução não pode ser aplicada duas vezes.

### RB-12 — Fretes com a Montana

Fretes fazem parte do escopo funcional confirmado. Cadastrar serviços locais e serviços ligados à viagem, com trecho de ida Apiaí → Curitiba ou volta Curitiba → Apiaí. Uma viagem pode conter vários fretes de clientes diferentes nos dois sentidos.

Registrar contratante, contato, endereço de coleta, endereço de entrega, data prevista, descrição e quantidade de objetos, valor combinado, vencimento e observações. Exemplos: fogão, geladeira e cama. Fotos e comprovantes podem ser acrescentados posteriormente. Evitar exigir cadastro extenso para um contratante eventual.

Situações operacionais: agendado, coletado, entregue ou cancelado. Situação financeira separada: a receber, parcialmente pago ou pago. Entregar um frete não comprova pagamento. Receber antecipado não comprova entrega: registrar como adiantamento vinculado ao serviço. Cancelamento com adiantamento exige indicar devolução ou crédito; não apagar o pagamento.

Objetos de terceiros não entram como estoque de hortifruti. Registrar coleta/entrega do objeto e receita do serviço. Se o contratante também compra verduras, mostrar uma conta consolidada com origem identificada — mercadorias ou frete — sem cobrar o mesmo serviço duas vezes.

Mostrar valores de fretes contratados, serviços entregues, pagamentos recebidos e saldo a receber separadamente. Resultado do frete considera receita dos serviços concluídos e custos atribuídos. Combustível/pedágio compartilhados com a compra no Ceasa exigem rateio explícito, com soma de 100%, sem lançar a mesma despesa integralmente no frete e na mercadoria. Receita do frete não reduz automaticamente o custo da compra.

No agendamento, revisar espaço e peso disponíveis para conciliar objetos com frutas e verduras. A primeira versão pode usar confirmação manual de capacidade; não prometer cálculo automático sem dimensões e pesos cadastrados.

## 6. Inventário de telas e continuidade


### Interfaces existentes e origem dos dados

| Interface | Abertura | Fonte atual | Continuação necessária |
|---|---|---|---|
| Início Gestão e Entregas | Rota `/`, `WorkspacePage` | Vendido e recebido saem da rua e dos recebimentos confirmados; a receber sai das contas; estoque baixo e movimentos do dia saem do catálogo | Contas a pagar, conferência do Ceasa e equipe ainda não têm lançamento |
| Nota da cliente | `/customers/{id}` | Cliente, rascunho e entrega confirmada no SQLite; a conta mostra saldo, recebimentos e cobranças; vendas antigas da rua continuam no ledger | Correção de nota entregue fica para a etapa seguinte. O total do rascunho não é dívida até a confirmação |
| Editar item | Painel na nota | Grava na hora o rascunho aberto e recalcula o total em centavos | Depois da entrega, corrigir só a diferença |
| Adicionar item | Catálogo aberto pela nota | O item entra no rascunho com o produto, o nome exibido, a unidade e o preço praticado | Depois da confirmação, baixar o estoque na mesma transação da venda |
| Estoque e produto | Aba Estoque e “Ver produto” | `pouapp_catalog.db` | Saldo por local, histórico e a operação de origem. Reserva e disponível para pedido ainda não existem |
| Clientes | `/customers`, `/customers/new`, `/customers/{id}/edit` | `pouapp_customers.db` | Importar os cadastros reais sem duplicar |
| Fretes | Tela aberta pelo atalho Frete | SharedPreferences | Tratar viagem passada sem conclusão como pendência, não como próxima viagem |
| Chave Pix | Aba Ajustes da Gestão | Perfil do negócio no catálogo | Reutilizar tipo, chave e nome do recebedor na cobrança. Não gerar QR Code nem Copia e Cola |
| Cobrança | Conta da cliente e visita do dia | Mensagem preparada no catálogo | Abrir uma conversa por cliente, com a mensagem preenchida. Não registrar pagamento nem afirmar entrega |

Essas telas devem ser aproveitadas. A tabela seguinte descreve cobertura funcional desejada, não uma ordem para recriar interfaces existentes.

### Regras a esclarecer nas telas apresentadas

**Nota versus conta:** o valor de uma nota é a soma de seus itens e descontos; a conta da cliente reúne os valores em aberto de todas as notas e pagamentos. Exibir rótulos distintos: “Total desta nota” e “Saldo devedor da cliente”. Não presumir que os dois valores sejam iguais.

**Conferência dos valores:** o total da nota é a soma dos itens gravados, em centavos. Uma cliente sem rascunho começa em R$ 0,00. Os cinco itens de exemplo que somavam R$ 71 não são mais inseridos.

**Situação do rascunho:** a nota aberta mostra “Rascunho”. Isso não significa entregue, pago ou aprovado. O saldo devedor da cliente ainda não é calculado; o número em destaque é só o total dos itens desta nota. Quando a venda for confirmada, a situação operacional e a financeira precisam aparecer separadas.

**Edição:** nota em rascunho pode ter itens alterados sem movimentação definitiva. Para nota já entregue, editar quantidade/preço deve produzir correção rastreável e ajustar estoque e financeiro apenas pela diferença. Não baixar a quantidade inteira novamente. Nunca reescrever pagamentos existentes. Se a redução gerar valor pago a mais, registrar crédito ou reembolso explícito. Uma compra realizada em outro atendimento deve ser um novo lançamento, mesmo que o aplicativo a apresente na mesma conta.

**Vencimento:** alterar a data deve atingir a nota identificada, preservar os vencimentos das demais e registrar a mudança. Não renovar toda a dívida ao adicionar uma compra.

**Unidade e preço:** explicitar “pacote de 2 kg”, “pacote de 500 g”, “kg” ou “bandeja” ao editar. Uma unidade de pacote de 2 kg consome 2 kg equivalentes; alho de 500 g consome 500 g. Proposta: pacotes e bandejas usam quantidades inteiras; produto por kg aceita peso fracionado. Rótulo do preço deve indicar R$/pacote ou R$/kg conforme o item.

**Mensagem:** a ação existente pode abrir o contato/compartilhamento para o usuário enviar. Não enviar automaticamente ao salvar uma nota; automação de mensagens não faz parte deste fluxo inicial.

**Datas no Frete:** a captura está no período novembro de 2026, mas apresenta viagem de outubro como próxima e planejada. Validar com a data de referência: uma viagem passada sem conclusão deve aparecer como pendente/atrasada, e não como próxima futura. Se viagens fora do período forem exibidas, indicar o critério. Valores combinados, recebidos e a receber devem ter filtros claramente definidos; entradas antecipadas não podem ser contadas duas vezes.

### Cobertura funcional planejada

| Tela | Conteúdo e ação principal | Validação essencial |
|---|---|---|
| Produtos | Busca, unidade, apresentações, preço e mínimo | Não converter unidades incompatíveis |
| Clientes | Busca por nome/telefone e endereço | Evitar importações duplicadas |
| Conta da cliente | Saldo em destaque, adicionar compra, receber pagamento e histórico | R$ 150 + compra fiada de R$ 30 = R$ 180 |
| Clientes do dia | Seleção múltipla, ordem e motivo da visita | Seleção não movimenta estoque/financeiro |
| Fretes | Agenda, trecho, objetos, coleta, entrega e cobrança | Entrega e pagamento independentes |
| Viagens e compras | Fornecedores, itens, custos e pagamentos | Separar comprado de recebido |
| Recebimento | Previsto, aceito, diferença e destino | Confirmar entrada uma vez |
| Estoque | Saldo por produto, apresentação e local | Mostrar físico, reservado e disponível |
| Histórico do produto | Todas as entradas, saídas e ajustes | Abrir operação de origem |
| Pesagem | Granel consumido, pacotes, sobra e perda | Balanço de peso deve fechar |
| Carga da Montana | Produtos, quantidades e confirmação | Não exceder disponível |
| Rota do dia | Clientes, ordem e situação | Venda na porta sem pedido prévio |
| Nova venda | Cliente, itens, preço, desconto e pagamento | Usar estoque do local escolhido |
| Confirmar entrega | Quantidades reais e condição de pagamento | Criar saída e dívida atomicamente |
| Receber pagamento | Cliente, valor, meio e dívidas quitadas | Conferir distribuição e excedente |
| Despesas/contas a pagar | Categoria, viagem, vencimento e quitação | Evitar pagamento duplicado |
| Fechamento da rota | Carga, retorno, perdas e recebimentos | Explicar diferenças |
| Financeiro | Vendido, recebido, vencido, despesas e resultado | Período e critério visíveis |
| Sincronização | Pendências, erros e nova tentativa | Preservar operações após falha |

## 7. Modelo conceitual de dados

| Entidade | Responsabilidade |
|---|---|
| Produto / Apresentação | Unidade-base, formato de venda e conversões válidas |
| Cliente / Endereço | Identidade e dados de atendimento |
| Fornecedor | Origem das compras |
| Viagem / Compra / ItemCompra | Aquisição e despesas associadas |
| Recebimento / ItemRecebimento | Quantidade aceita e origem do custo |
| LocalEstoque | Depósito, veículo e transporte |
| MovimentoEstoque / Alocação | Efeito físico e recebimentos consumidos |
| Transformação | Pesagem, embalagem, sobra e perda |
| Reserva | Compromisso de estoque para pedido |
| Rota / Parada / Carga | Operação de entrega e transferências |
| Pedido / ItemPedido / Entrega | Solicitação, valores e atendimento real |
| ContaReceber / Pagamento / AlocaçãoPagamento | Dívida e quitação sem duplicidade |
| ContaPagar / PagamentoFornecedor | Obrigações e pagamentos do negócio |
| Despesa / Rateio | Gastos e destino do custo |
| Devolução / Estorno | Correção física e financeira rastreável |
| Frete / ObjetoFrete / Adiantamento | Serviço, objetos de terceiros e pagamento antecipado |
| OperaçãoPendente | Sincronização com identificador estável |

Usar IDs estáveis gerados no aparelho para operações offline. Valores monetários usam inteiros em centavos; peso em gramas. Quantidade por unidade/maço deve respeitar a precisão permitida no produto. Não usar ponto flutuante para dinheiro. Guardar os valores praticados nos itens, sem depender do preço atual do cadastro.

## 8. Requisitos técnicos de continuidade

O aplicativo já usa Flutter, `flutter_bloc`, `get_it` e `sqflite`. Clientes continuam no banco de clientes. Catálogo, saldo inicial, rascunhos e a operação de rua ficam no banco do catálogo, que é a base ativa depois da migração. O modo e os fretes continuam em SharedPreferences. A fila de sincronização fica no aparelho e só é marcada como enviada quando um servidor confirmar; hoje não há servidor. Novas gravações devem seguir repositório, regra de domínio e tela, sem introduzir outro mecanismo de estado.

Salvar operação local e efeitos de estoque/financeiro na mesma transação. Sincronizar com uma chave idempotente permanente. Manter pendências após fechar o processo, perder rede ou expirar sessão. Só mostrar “sincronizado” após confirmação do servidor.

Na primeira versão, limitar movimentações de estoque a um aparelho operador. Antes de habilitar vários aparelhos simultâneos, definir autoridade do saldo, reservas por dispositivo e resolução de conflitos: operações offline concorrentes podem consumir o mesmo estoque. Não resolver isso sobrescrevendo silenciosamente o último saldo.

Separar credenciais dos dados operacionais, restringir acesso, prever backup/restauração e evitar dados pessoais em logs. Recuperar acesso não pode apagar contas ou pendências. Testar restauração antes de depender do aplicativo na operação real.

Importação das mais de 400 clientes deve ter prévia, mapeamento de campos, relatório de erros e prevenção de duplicidade. Dívidas antigas entram como saldo inicial identificado, sem criar venda atual. Estoque inicial e dinheiro inicial também precisam de lançamentos próprios com data de corte.

## 9. Ordem de implementação

| Etapa | Entrega concreta | Critério para avançar | Situação em 3 de novembro de 2026 |
|---|---|---|---|
| 0 — Fundação | Revisão do código, banco local, navegação e estados vazios | Fechar e abrir mantém dados; início não exibe números fictícios | Navegação e bancos locais existem. Vendido, recebido e a receber usam lançamentos gravados. Ceasa, equipe e contas a pagar aparecem como “Ainda não disponível” |
| 1 — Cadastros e estoque inicial | Produtos, clientes, locais e movimentos | Cadastrar/importar e conferir saldo inicial | Produto, três locais, saldo inicial, carga, retorno, perda e conferência estão gravados. Falta importar clientes e dívidas reais |
| 2 — Compra até depósito | Compra, recebimento e divergência | Compra de 100 kg com 97 kg recebidos fica explicada | Não iniciada |
| 3 — Pesagem e carga | Transformações e transferência para Montana | Balanço de peso fecha sem duplicação | A transferência Depósito ↔ Montana está gravada. A tela de pesagem da batata calcula sacos e embalagens e ainda não grava essa separação |
| 4 — Venda e fiado | Venda na porta, entrega, contas e pagamento parcial | Venda baixa carga e pagamento reduz dívida corretamente | A entrega confirmada baixa a Montana, cria a dívida e aceita pagamento parcial. A correção da nota entregue ainda não existe |
| 5 — Entregas e fretes | Clientes do dia, conta rápida, rota, retorno e fretes locais/ida/volta | Conta da cliente confere; frete não altera estoque de verduras | Lista do dia, fretes e rascunho da nota são gravados. A cobrança abre o WhatsApp de uma cliente por vez. O rascunho ainda não é entrega nem dívida |
| 6 — Custos e gestão | Despesas, rateio, contas a pagar e indicadores | Resultado distingue lucro de dinheiro recebido | Não iniciada |
| 7 — Operação assistida | Backup, recuperação, importação final e piloto | Um ciclo real confere com controle manual | Não iniciada |

A persistência offline deve existir desde a fundação. A sincronização entra com os primeiros fluxos confirmados, sem ser adiada como adaptação final. Executar um fluxo vertical pequeno antes de construir todos os módulos: produto → entrada → carga → venda fiada → pagamento parcial.

Fora do escopo inicial: emissão fiscal, roteirização automática, envio automático de WhatsApp, reconhecimento de áudio, balança integrada, integração bancária e confirmação automática de Pix. A cobrança atual só preenche a conversa; a pessoa envia. Podem ser acrescentados após o fluxo principal estar confiável.

## 10. Cenários de aceitação

1. **Compra divergente:** comprar 100 kg e aceitar 97 kg. Depósito mostra 97 kg; diferença de 3 kg permanece identificada e sua solução financeira é explícita.
2. **Embalagem:** consumir 10 kg de alho, produzir 19 pacotes de 500 g e devolver 500 g ao granel. Total físico permanece 10 kg.
3. **Transferência:** carregar 40 kg a partir de 100 kg no depósito. Depósito fica com 60 kg e Montana com 40 kg; não há receita.
4. **Venda fiada:** entregar R$ 80 com vencimento em 30 dias. Estoque da Montana baixa, vendido aumenta R$ 80, recebido permanece zero e dívida fica R$ 80.
5. **Pagamento parcial:** receber R$ 30 dessa venda. Dívida passa a R$ 50; vendido permanece R$ 80.
6. **Dívida antiga:** receber R$ 100 de saldo inicial. Recebido aumenta R$ 100; vendas do dia não mudam.
7. **Reserva:** reservar 5 kg entre 20 kg físicos. Disponível fica 15 kg; cancelar libera os 5 kg sem entrada física.
8. **Retorno:** com carga de 40 kg, vender 25 kg, perder 2 kg e retornar 13 kg. Veículo fecha zerado e depósito recebe somente 13 kg.
9. **Devolução:** receber produto vendido de volta; escolher aproveitável ou perda e registrar abatimento/crédito/reembolso correspondente.
10. **Reenvio:** confirmar venda offline, fechar aplicativo, abrir e sincronizar duas vezes. Deve existir uma venda, uma saída e uma dívida.
11. **Correção:** tentar apagar venda entregue. Sistema oferece estorno rastreável e não remove o histórico.
12. **Rateio:** distribuir R$ 100 entre compras de R$ 200 e R$ 300. Custos adicionais ficam R$ 40 e R$ 60; despesa não é deduzida novamente no resultado.

13. **Conta rápida:** cliente deve R$ 150, compra 1 kg de alho por R$ 30 fiado e passa a dever R$ 180. Baixar 1 kg da Montana sem alterar compras antigas.
14. **Atendimento:** selecionar cliente, vender e marcar atendida sem pagamento. Dívida permanece e progresso do dia avança apenas ao concluir visita.
15. **Frete de ida e volta:** registrar geladeira na ida e cama na volta. Os objetos não aumentam estoque de produtos; cada serviço conserva seu valor e situação financeira.
16. **Frete antecipado:** receber antes da coleta. Registrar adiantamento; reconhecer serviço entregue sem criar segunda entrada de dinheiro.
17. **Despesa compartilhada:** atribuir R$ 60 de combustível à compra e R$ 40 ao frete. Total registrado continua R$ 100.

18. **Nota em rascunho:** abrir uma cliente sem nota mostra zero itens e o total R$ 0,00, com a situação “Rascunho”. Adicionar um produto, alterar quantidade e preço e escolher o vencimento grava na hora. Fechar e abrir de novo recupera o mesmo rascunho. Isso não muda estoque, vendido, recebido nem a venda da rua. A confirmação, a baixa e a dívida ainda não existem.
19. **Correção de nota entregue:** corrigir quantidade já entregue sem duplicar baixa de estoque ou apagar pagamento; aplicar apenas a diferença e preservar histórico.
20. **Viagem passada:** com data de referência em novembro, viagem de outubro não concluída aparece como pendência, não como próxima viagem futura.
21. **Dinheiro parcial:** dívida de R$ 150 e recebimento de R$ 50 em dinheiro deixam saldo de R$ 100. Não nasce venda do dia. Repetir a confirmação não recebe de novo.
22. **Troco:** dívida de R$ 80, cliente entrega R$ 100 e recebe R$ 20. O pagamento gravado é R$ 80. Os R$ 20 não viram crédito nem recebido.
23. **Pix conferido:** um Pix parcial, informado depois da conferência, reduz a dívida escolhida e entra no recebido uma vez, identificado como Pix.
24. **Cobrança sem pagamento:** abrir o WhatsApp, ou falhar ao abrir, mantém a dívida e o recebido. A prévia continua disponível para copiar. O histórico diz “Cobrança preparada” ou “WhatsApp aberto”.
25. **Saldo depois do parcial:** depois de receber parte, a mensagem cobra o valor que ainda está em aberto.
26. **Cadastro incompleto:** sem telefone ou sem chave Pix, a cobrança oferece completar o cadastro e não registra pagamento.
27. **Clientes separadas:** a prévia de uma cliente mostra só o nome, o telefone, o valor e a mensagem dela. O recebimento de uma não altera a outra.
28. **Estorno:** estornar devolve o saldo e conserva o meio, dinheiro ou Pix. O valor deixa de entrar no recebido. Um segundo estorno do mesmo recebimento não duplica.
29. **Entrega fiada:** dívida anterior de R$ 150 e 1 kg de alho a R$ 30 deixam a conta em R$ 180. A Montana perde 1 kg. O vendido sobe R$ 30. O recebido não muda.
30. **Pagamento na entrega:** os mesmos R$ 180, com R$ 50 distribuídos de forma explícita entre a compra e a dívida anterior, deixam R$ 130. À vista, parcial, dinheiro com troco e Pix manual seguem a mesma confirmação.
31. **Estoque insuficiente:** dois itens do mesmo produto são somados antes da conferência. Se a Montana não cobre, nada é gravado. Produto inativo, item sem vínculo e unidade sem conversão cadastrada também impedem a confirmação.
32. **Repetição:** confirmar de novo, ou reabrir depois do commit, recupera a mesma venda. “Nova compra” cria outro rascunho. Mudar o preço do catálogo não altera a nota entregue.
33. **Cobrança depois da entrega:** a mensagem pode usar o saldo restante da nota. A nota quitada não entra como cobrança pendente. Abrir o WhatsApp não recebe o valor.

## 11. Próxima tarefa para o desenvolvimento

A base ativa da operação é o arquivo `pouapp_catalog.db`, versão 5. Estoque, rascunho, entrega confirmada, visitas, vendas e pagamentos da rua, dívidas, recebimentos e cobranças preparadas ficam nessa conexão. A correção de uma entrega, a compra no Ceasa, a pesagem e o servidor continuam fora desta etapa.

A carga já é uma transferência real. “Carregar Montana” mostra o que já está na caminhonete e só transfere a diferença. Abrir a tela de novo não tira essa carga. A mercadoria sai da Montana quando a pessoa reduz ou remove na carga, quando devolve ao depósito, ou quando a encomenda é entregue à cliente. “Retornar ao depósito” devolve sobra. “Registrar perda” exige quantidade, local e motivo. “Conferir estoque” grava a quantidade contada e a diferença calculada. Tudo fica no histórico do produto, com acesso à operação. A Disponibilidade mostra só o que está na Montana. Encerrar a visita não mexe nesse saldo.

A rua antiga, em SharedPreferences, e os rascunhos antigos, no banco de clientes, permanecem como origem. A importação só marca a base nova como ativa depois de conferir contagens, vínculos e totais, na mesma transação. Repetir a abertura não duplica. Falha no meio desfaz a cópia e o aplicativo continua na origem. Depois do sucesso, a gravação nova vai só para a base ativa. Venda importada fica identificada como legado, sem data inventada e sem produto quando o registro antigo não tinha. Venda feita depois da migração grava a data do fato e a data de registro. O filtro mensal do extrato continua desligado para não tratar venda sem data como venda do mês. Frete continua em SharedPreferences; a integração financeira dele fica para depois.

A correção de venda entregue, a compra no Ceasa, a pesagem e o servidor continuam pendentes. Não antecipá-los na próxima etapa.

### Roteiro manual da carga

1. Abra um aparelho que já tinha produtos, rascunho e rua. Os saldos iniciais, os identificadores e a nota em rascunho continuam. O arquivo do catálogo passa para a versão 5 sem apagar esses lançamentos.
2. Cadastre um produto em quilogramas com saldo inicial de 100 kg no Depósito, ou use um saldo que você controle. A Montana começa em zero. A Disponibilidade diz que a Montana está sem carga.
3. Em Estoque, toque em “Carregar Montana”. A tela mostra a caminhonete e os produtos do depósito. Toque em Adicionar na banana, informe 40 kg e confirme o carregamento. O Depósito fica com 60 kg e a Montana com 40 kg. A Disponibilidade passa a mostrar 40 kg. O vendido, o recebido e a nota da cliente não mudam.
4. Se a confirmação falhar, a tela permanece com os mesmos produtos. Corrija e confirme de novo: é a mesma carga, não uma segunda. Depois de gravada, repetir aquele identificador não move outra vez. Uma carga nova é outra operação.
5. Toque em “Retornar ao depósito” e devolva 13 kg. O Depósito fica com 73 kg e a Montana com 27 kg.
6. Toque em “Registrar perda”, escolha a Montana, informe 2 kg e um motivo. A Montana fica com 25 kg. O Depósito continua com 73 kg.
7. Tente carregar mais do que há no Depósito, ou misture um produto válido com outro que não caiba. Nada muda e a lista digitada continua na tela.
8. Toque em “Conferir estoque”, informe a quantidade física e o motivo. O saldo do local vira essa quantidade e o histórico mostra a diferença. O lançamento anterior continua lá.
9. Abra o produto e, no histórico, abra a operação. Dá para ver origem, destino, produtos e quantidades. Feche o aplicativo e abra de novo: os mesmos saldos e o mesmo histórico aparecem.
10. Conclua uma visita da rua. A carga da Montana permanece. A conclusão não gera venda nem dívida.

### Roteiro manual do recebimento e da cobrança

1. Em Ajustes, salve o tipo da chave, a chave Pix e o nome do recebedor. Essa chave é texto. A tela não gera QR Code nem código Copia e Cola.
2. Na conta da cliente, registre um saldo inicial de R$ 150. O vendido do dia não muda e o estoque não muda. A receber passa a incluir esses R$ 150.
3. Receba R$ 50 em dinheiro, com a data de hoje e essa dívida marcada. Antes de confirmar, confira saldo anterior R$ 150, valor recebido R$ 50 e saldo restante R$ 100. Depois de gravar, o recebido sobe R$ 50 uma vez e o saldo fica R$ 100.
4. Em outra dívida de R$ 80, informe valor recebido R$ 80 e valor entregue pela cliente R$ 100. O troco aparece como R$ 20. O pagamento gravado é R$ 80. Os R$ 20 não ficam como crédito.
5. Registre um Pix parcial já conferido. Ele entra como Pix, separado do dinheiro. Enviar a cobrança ou voltar do WhatsApp não faz esse lançamento.
6. Envie a cobrança do saldo restante. A mensagem mostra o valor que ainda está aberto, a chave e o recebedor. Abra o WhatsApp e confira que a conversa é só daquela cliente. Toque em Enviar lá, se quiser. Ao voltar, a dívida e o recebido continuam iguais.
7. Repita a abertura da mesma cobrança. Continua um único preparo. Se o telefone ou a chave faltarem, complete o cadastro. Se o WhatsApp não abrir, copie a mensagem e a chave pela prévia.
8. Estorne um recebimento. O meio continua dinheiro ou Pix, o saldo da dívida volta e o valor sai do recebido. Estornar de novo não duplica.

### Roteiro manual da entrega

1. Deixe 1 kg de alho na Montana, por uma carga já confirmada. A cliente tem R$ 150 de saldo inicial.
2. Na nota dela, adicione 1 kg de alho a R$ 30 e escolha o vencimento desta compra. O rascunho ainda não muda estoque, vendido nem dívida.
3. Toque em “Confirmar entrega”. A revisão mostra a cliente, o alho, o total de R$ 30, o saldo anterior de R$ 150, o vencimento e o saldo previsto de R$ 180. Confirme sem pagamento. A Montana fica sem esse quilo, o vendido sobe R$ 30 e o recebido não muda. A conta fica em R$ 180. A nota aparece como entregue.
4. Toque de novo na confirmação, ou feche e abra a cliente. Continua uma venda. A edição direta fica bloqueada, com o aviso de que a correção virá numa etapa própria.
5. Em outra cliente, ou depois de “Nova compra”, repita a entrega e informe R$ 50. Marque esta compra e a dívida anterior. A revisão mostra a distribuição antes de gravar. O saldo previsto fica R$ 130. Dinheiro com troco e Pix manual usam a mesma tela. O troco não vira crédito.
6. Tente entregar mais do que há na Montana, inclusive o mesmo produto em dois itens. A mensagem explica a falta e nada é gravado. Um item sem produto, um produto inativo ou uma caixa de um produto em quilogramas também são recusados, porque não há conversão cadastrada.
7. Mude o preço do alho no catálogo. A nota já entregue conserva o preço praticado.
8. Envie a cobrança do saldo restante. A nota quitada não aparece nessa escolha. Abrir o WhatsApp não recebe o valor.

## 12. Assistente de voz

O microfone no canto inferior direito é o mesmo nos modos Entregas e Gestão. O rótulo de acessibilidade é “Assistente de voz”. O painel abre por cima da tela e respeita a área segura. Ao abrir, ele escuta e mostra “Pode falar”, a transcrição conforme ela chega e “Ouvindo…” só enquanto o microfone está de fato aberto. Não há campo de texto, botão Digitar nem leitura da resposta em voz. Parar interrompe a captura sem gravar o que estava pela metade. Retomar volta a escutar. Fechar encerra a sessão. Enquanto busca, o painel diz o que está procurando. Uma dúvida mostra a pergunta e, quando há opções, a lista. O resultado mostra a resposta, a nota atualizada quando houve inclusão, a conta quando a pergunta foi de dívida, e desfazer quando houve anotação. O painel continua aberto e, depois de um breve intervalo, escuta o próximo comando. Silêncio ou frase não compreendida preserva o contexto e retoma a escuta. Permissão negada, serviço indisponível, falta de rede ou duas falhas seguidas param as tentativas e mostram o problema, com Retomar. “Cadastrar apelido” aparece quando um nome ou uma abreviação não foi resolvida.

Ele não grava em segundo plano. A sessão do assistente usa escutas sequenciais: uma termina antes da próxima começar. Parar, fechar o painel ou deixar o aplicativo em segundo plano cancela a captura e descarta um reconhecimento atrasado. Ao voltar para o primeiro plano, a escuta recomeça se o usuário não tinha parado. Enquanto o painel segue aberto, a cliente da última anotação ou consulta permanece no topo, como “Atendendo Ricardo Alves”. Outra frase sem nome, ou com “ele”, “ela”, “para ele” ou “nesse cliente”, usa essa cliente. Outro nome troca a cliente. “Cancelar”, “corrigir” e “trocar de cliente” limpam o que estava pendente. Depois de três minutos sem interação, “ela” pede confirmação antes de valer. Fechar o painel encerra esse atendimento.

Nesta etapa o assistente executa o que já tem regra de domínio:

- Consultar cliente, notas, dívida, vencimentos, pagamentos e crédito. Exemplo: “Quanto a Maria MT me deve?” O rascunho não entra nessa dívida.
- Adicionar um ou vários produtos ao rascunho, inclusive na mesma frase. Exemplo, com Ricardo Alves em atendimento: “E adicione um quilo de alho e um quilo de batata.” Também valem “coloca também”, “mais um quilo” e “para ele”. A frase inteira é resolvida antes de gravar. Se um item ficar sem unidade, como “duas batatas” num produto por quilo, o painel pergunta “Batata: duas unidades ou dois quilos?” e não grava o outro item antes da resposta. Os dois entram na mesma gravação, com um identificador da solicitação.
- Anotar preço combinado e a diferença para o preço de referência, como desconto só de exibição.
- Alterar o preço de uma linha do rascunho.

O prazo e o pagamento da compra em atendimento também entram por voz. “Ela paga dia quinze”, “para daqui a trinta dias” e “mude o vencimento para vinte de novembro” alteram só o rascunho aberto e mostram a data completa. Data ambígua, mês já passado ou ano não dito quando a data deste ano já passou pedem esclarecimento e não gravam. “Vai ficar fiado”, “pagou tudo em dinheiro”, “recebi vinte reais em dinheiro” e “conferi o Pix de vinte reais” ficam guardados até a confirmação. “Vou mandar o Pix” não é pagamento recebido. O valor pago e o valor entregue aparecem separados quando há troco. O pagamento quita esta compra. A dívida anterior só entra se a frase pedir e a revisão mostrar a distribuição.

“Confirmar entrega” mostra cliente, itens, total, vencimento do restante, pagamento, meio, troco, dívida anterior, saldo previsto e a saída prevista da Montana. “Confirmar” grava pela mesma transação da tela: venda, saída da Montana, dívida e pagamento opcional. “Corrigir” e “Cancelar” não gravam. Se a nota, o pagamento ou o saldo mudarem, a revisão anterior não vale. Repetir a mesma confirmação não repete o efeito. Depois da entrega, o painel continua com a cliente e a compra seguinte abre outro rascunho.

Ainda não são executados por voz: consultar o estoque fora dessa revisão, organizar visitas, consultar frete, preparar cobrança Pix, estornar e receber uma dívida antiga sem deixar isso explícito na revisão.

A frase vira um comando com intenção e campos. Esse comando não executa SQL e não altera saldo por conta própria. A inclusão usa o rascunho já existente da cliente, ou abre um rascunho novo quando a última nota já foi entregue. A consulta lê as contas a receber e os pagamentos já gravados. Um quilo entra como 1.000 gramas. Se o produto é vendido por unidade, maço, caixa ou dúzia, uma quantidade em quilos pede esclarecimento. Cada solicitação recebe um identificador próprio. O resultado parcial, o resultado final e uma nova tentativa de gravar essa mesma solicitação produzem um único acréscimo. Dizer a mesma frase de novo, numa solicitação nova, acrescenta outra vez. Sem preço na frase, o produto que já está na nota aumenta a quantidade e conserva o preço praticado. Um produto novo entra com o preço do catálogo.

“Cliente Adriele, melancia quinze reais” anota o preço combinado. O cadastro do produto permanece, por exemplo, em R$ 25. A linha guarda esse preço de referência e o preço praticado de R$ 15. O total da nota usa só o praticado, e a diferença aparece como desconto, sem ser subtraída de novo. Não se pede motivo. Se o produto é vendido por unidade e a quantidade não foi dita, entra uma unidade e a resposta diz isso: “Anotei uma melancia por quinze reais para Adriele.” Se é por quilo, o assistente pergunta a quantidade e se o valor é o preço do quilo ou o total. Uma linha que já está por outro preço permanece; a unidade nova abre outra linha. “Mude a melancia para quinze reais” altera o preço de uma linha do rascunho. Se houver mais de uma, pergunta qual. A nota entregue não é alterada. Depois de gravar, o painel mostra os itens e o total e a tela da cliente, se estiver aberta, é atualizada sem fechar o assistente.

Cliente é resolvida por nome, apelido e bairro. JP já significa Jardim Paraíso. MT não tem significado até alguém cadastrar a abreviação em Configurações do assistente. Dá para cadastrar apelido de cliente ou abreviação de bairro. Se houver duas pessoas ou dois produtos possíveis, o painel lista as opções e guarda a intenção, o produto e a quantidade já entendidos. A resposta pode ser por toque ou falando, por exemplo, “Maria do Jardim Paraíso”. O primeiro resultado não é escolhido sozinho. Cliente, produto, unidade ou quantidade ausentes também pedem esclarecimento.

O rascunho gravado não confirma venda, não baixa estoque e não cria dívida. “Desfazer este comando” retira só o acréscimo daquela solicitação. Se a linha já tinha quantidade, ela volta ao valor anterior. Se a linha foi editada depois, ela permanece, e as outras linhas da nota também. Cancelar ou fechar o painel invalida um resultado que chegue atrasado: ele não grava.

A consulta abre os dados da conta no próprio painel: nome, bairro, saldo devedor, valor vencido, notas com vencimento, itens quando a venda os tem, pagamentos e crédito separados. Saldo antigo sem itens aparece como registro sem itens detalhados. O rascunho da nota não entra nessa dívida. A resposta fica só na tela. O pacote `flutter_tts` permanece no projeto, mas o painel não chama a síntese de voz.

O reconhecimento usa `speech_to_text` 7.5.0, o reconhecedor do aparelho, para uma frase curta. Não há serviço externo nem credencial. O áudio bruto não é salvo. No Android, o reconhecedor costuma depender de internet; o modo no aparelho só funciona se houver um pacote de idioma instalado, e o sistema pode recusar esse modo. No iOS, o reconhecimento no aparelho falha quando o modelo offline de português não está instalado. Por isso o aplicativo não promete reconhecimento offline. Sem rede e sem pacote local, o painel explica a falha e espera Retomar. Se o modo no aparelho falhar uma vez, a escuta tenta de novo pelo serviço do sistema.

Permissões: microfone no Android e no iOS, e reconhecimento de fala no iOS. O Android também declara internet, Bluetooth e as consultas ao reconhecedor e ao serviço de voz do sistema, exigidas pelos pacotes.

Os testes automáticos cobrem a frase de Ricardo Alves, dois produtos na mesma frase, os conectivos, o esclarecimento do segundo item sem gravar o primeiro, a repetição da mesma solicitação, uma frase nova igual, o desfazer do conjunto e a ausência de síntese de voz. Também cobrem prazo ambíguo ou já passado, fiado com venda de R$ 30 somada a uma dívida de R$ 150, pagamento parcial, troco, Pix ainda não recebido, estoque insuficiente, revisão invalidada, confirmação repetida, cancelamento e uma nova data depois da falha de estoque. Nada disso foi conferido no iPhone físico. Ainda falta, no aparelho: a retomada da escuta depois do silêncio e depois de um comando, a interrupção por ligação ou segundo plano, a permissão negada e a permissão concedida em seguida, e se o microfone não permanece ativo com o aplicativo fechado.

## 13. Perguntas para a próxima revisão

- As vendas acontecem por encomenda, na porta ou das duas formas?
- Quem recebe e pesa a mercadoria? Haverá mais de um aparelho alterando estoque?
- Os pacotes têm peso fixo ou cada pacote é vendido pelo peso real?
- Onde estão os cadastros atuais e as dívidas das clientes?
- Quais meios de pagamento são usados e como você confere os recebimentos?
- O recebimento físico já pode ocorrer no Ceasa ou só deve ser confirmado no depósito?

Essas respostas refinam a proposta. A carga da Montana transfere saldo. A conta da cliente recebe dinheiro e Pix, calcula troco e prepara a cobrança no WhatsApp. A entrega confirmada grava, na mesma transação, a venda, a saída da Montana, a dívida e o pagamento opcional. A correção dessa entrega, a compra no Ceasa e a pesagem continuam posteriores. A etapa 2, da compra até o depósito, continua posterior.
