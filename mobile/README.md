# PouApp

Aplicativo Flutter do PouApp, um SaaS de gestão empresarial multiempresa.

Este pacote contém somente o cliente mobile. Os diretórios `backend` e `web`, na raiz do repositório, estão reservados e ainda não possuem código. As features atuais são a autenticação simulada em `lib/features/auth` e a gestão de clientes em `lib/features/customers`.

## Arquitetura

A organização segue a Clean Architecture do projeto de referência `flutter-tdd-clean-architecture-course`.

A regra de dependência aponta para o domínio:

`presentation` → `domain` ← `data`

`domain` não importa Flutter, HTTP, cache nem detalhes de dispositivo. `data` implementa os contratos do domínio. `presentation` chama casos de uso e reage a `Either<Failure, T>`.

O service locator fica em `lib/injection_container.dart` (`sl`). `main` inicializa o binding do Flutter, chama `di.init()` e só então executa o aplicativo.

## Responsabilidade de cada camada

Cada feature futura fica em `lib/features/<feature>/` e se divide em três camadas.

### domain

- `entities`: objetos de negócio. Estendem `Equatable` para igualdade por valor.
- `repositories`: contratos abstratos. Os métodos retornam `Future<Either<Failure, T>>`.
- `usecases`: uma ação da aplicação por classe. Implementam `UseCase<T, Params>` e expõem `call`. Parâmetros próprios ficam numa classe `Params` no mesmo arquivo. Casos de uso sem parâmetro recebem `NoParams`. O parâmetro de tipo se chama `T` para não sombrear `Type` do Dart.

### data

- `models`: estendem a entidade correspondente e fazem `fromJson` / `toJson`.
- `datasources`: fontes remota e local. Não capturam erro de negócio: lançam `ServerException` ou `CacheException`.
- `repositories`: implementam o contrato do domínio, convertem exceção em `Failure` e devolvem `Right` ou `Left`. Quando a fonte passar a ser uma API, a implementação consulta `NetworkInfo` antes da chamada remota. A autenticação simulada ainda não usa rede.

### presentation

- `bloc`: eventos e estados estendem `Equatable`. O bloc depende de casos de uso, não de repositórios nem de fontes de dados.
- `pages` e `widgets`: interface Material. A página observa o bloc e desenha o estado.

A API atual do `flutter_bloc` 9 registra o estado inicial no construtor e trata eventos com `on<Event>`:

```dart
class ExampleBloc extends Bloc<ExampleEvent, ExampleState> {
  ExampleBloc({required this.exampleUseCase}) : super(const ExampleInitial()) {
    on<ExampleRequested>(_onExampleRequested);
  }

  final ExampleUseCase exampleUseCase;
}
```

## Organização de `core` e `features`

`lib/core` guarda o que é compartilhado por todas as features:

| Caminho | Responsabilidade |
| --- | --- |
| `core/error/failures.dart` | Falhas de domínio: `Failure`, `ServerFailure`, `CacheFailure`. |
| `core/error/exceptions.dart` | Exceções das fontes de dados: `ServerException`, `CacheException`. |
| `core/usecases/usecase.dart` | Contrato `UseCase<T, Params>` e `NoParams`. |
| `core/network/network_info.dart` | Abstração `NetworkInfo` e implementação que consulta a conectividade. |

`lib/features/auth` é a primeira feature. O projeto de referência usa `core/util` para conversores compartilhados; o conversor existente lá era específico do exemplo de number trivia e não foi copiado. A validação de e-mail e senha do login fica em `features/auth/presentation/validation`, porque pertence ao formulário e não ao domínio.

Falhas específicas de uma feature ficam na própria feature, não em `core/error`.

## Estratégia de TDD

Os testes espelham `lib`:

```text
test/
├── core/
├── features/<feature>/
│   ├── data/
│   ├── domain/
│   └── presentation/
├── fixtures/
│   └── fixture_reader.dart
└── widget_test.dart
```

Ordem usada no projeto de referência, de dentro para fora:

1. Entidade.
2. Contrato do repositório.
3. Caso de uso, começando pelo teste.
4. Model, com serialização coberta por teste.
5. Data sources, com teste e fixtures JSON.
6. Implementação do repositório, com teste.
7. Bloc, com teste.
8. Página e widgets.
9. Registro em `injection_container.dart`, de cima para baixo: bloc (`registerFactory`), casos de uso, repositório, data sources, depois dependências externas.

Convenções dos testes:

- Descrição no formato `should ...`.
- Comentários `arrange`, `act` e `assert`.
- Valores de teste prefixados com `t` (`tCustomer`, `tNumber`).
- Mocks manuais com `mocktail`: `class MockX extends Mock implements X {}`.
- JSON de fixture lido por `fixture('nome.json')`, com o arquivo em `test/fixtures/`.

Os testes de `auth` cobrem entidade, casos de uso, model, fontes simulada e local, repositório, bloc, validação e o fluxo de telas. Os testes de `core` continuam válidos.

## Autenticação simulada

A feature `auth` não chama backend. Em build de debug, o login aceita somente esta conta fictícia:

| Campo | Valor |
| --- | --- |
| E-mail | `mike@gmail.com` |
| Senha | `mike@123` |
| Nome exibido | Mike |

Essas credenciais existem apenas para a simulação de desenvolvimento. Não são uma conta real e não devem ser reutilizadas fora deste aplicativo. A senha não é gravada no aparelho nem escrita em log. A sessão guarda somente `id`, `name` e `email`.

A simulação segue o modo de compilação do Flutter, o mesmo critério de `kDebugMode`: fica desligada em profile (`dart.vm.profile`) e release (`dart.vm.product`). Não há flag de runtime capaz de ligá-la nesses modos. Se o modo não for debug, o login falha e uma sessão antiga não é restaurada.

Fluxo:

1. Ao abrir, o `AuthBloc` consulta a sessão.
2. Com sessão válida, abre a tela de Entregas, com o nome e o e-mail.
3. Sem sessão, abre o login.
4. O botão Sair apaga a sessão e volta ao login sem empilhar rota. O botão Voltar não retorna à tela autenticada.

Para trocar a simulação pela API Node.js no futuro, implemente `AuthRemoteDataSource` com HTTP e registre essa classe no lugar de `SimulatedAuthRemoteDataSource`. O contrato do repositório, os casos de uso e as telas permanecem. O armazenamento local deve passar a guardar o token real em um mecanismo seguro, não em `shared_preferences`.

## Gestão de clientes

A feature `customers` cadastra e consulta clientes no aparelho, sem backend. O domínio não conhece SQLite, BLoC nem a futura API Node.js. A interface chama casos de uso e recebe `Either<Failure, T>`.

O banco local é SQLite (`sqflite`), no arquivo `pouapp_customers.db`. A pesquisa, o filtro por situação e a paginação acontecem na base, com colunas normalizadas para ignorar maiúsculas e acentos. O endereço principal e o contato principal são mantidos numa transação. `shared_preferences` continua exclusivo da sessão.

Esse arquivo é um armazenamento de desenvolvimento. Ele não tem coluna de empresa e não isola dados entre empresas. O isolamento real será feito no backend.

Em build de debug, a primeira abertura insere cinco clientes fictícios, uma única vez. Apagar ou editar um deles não faz o aplicativo recriar o registro. Profile e release não recebem esses dados. São todos fictícios:

| Cliente | Documento |
| --- | --- |
| Restaurante Primavera | CNPJ 11.222.333/0001-81 |
| Mercado Central | CNPJ 19.100.000/0001-91 |
| Hortifruti São José | CNPJ 33.444.555/0001-81 |
| Padaria Bom Sabor | CNPJ 55.666.777/0001-81 |
| João Oliveira | CPF 529.982.247-25 |

O Restaurante Primavera guarda `externalSource = contaAzul` e `externalId = demo-ca-primavera` só para exercitar a chave externa. Esse identificador não veio da API do Conta Azul. Uma segunda inclusão com a mesma origem e o mesmo identificador é recusada.

Depois do login, o botão Clientes abre a lista. O botão Voltar desfaz as telas de cliente antes de sair da área autenticada. O logout remove esse navegador interno, então o Voltar não reabre a lista.

Para substituir o banco local pela API, implemente outro `CustomerRepository` e registre essa classe no `injection_container.dart`. Entidades, casos de uso e telas permanecem.

## Tela principal

Depois do login, a sessão abre Entregas. A cor do cabeçalho fica em `WorkspaceColors`.

A tela principal é o roteiro de clientes do dia. Dá para incluir ou remover clientes, mudar a ordem das visitas e atender cada conta: venda, entrega e pagamento ficam em registros separados. Concluir a visita não quita a conta. Uma correção de compra guarda o valor anterior. O aviso pelo WhatsApp fica fora do aplicativo. O roteiro fica no aparelho, na chave `street_ledger` de `shared_preferences`.

Clientes abre o fluxo já existente. Carregar a Montana e retornar mercadoria ao depósito continuam na mesma tela. Não há balança, nota fiscal nem serviço externo.

## Como executar o aplicativo

Na pasta `mobile`, com um dispositivo ou emulador disponível:

```bash
flutter pub get
flutter run
```

O projeto foi criado para Android e iOS. A plataforma Flutter Web não faz parte deste pacote.

## Como executar os testes

Na pasta `mobile`:

```bash
flutter analyze
flutter test
```

Os testes de clientes usam SQLite em memória. Eles não gravam o banco do aplicativo.

## Como adicionar uma nova feature

A feature `customers` já segue esta organização:

```text
lib/features/customers/
├── data/
│   ├── datasources/
│   ├── models/
│   └── repositories/
├── domain/
│   ├── entities/
│   ├── repositories/
│   └── usecases/
└── presentation/
    ├── bloc/
    ├── pages/
    └── widgets/
```

Repita a mesma árvore em `test/features/customers/`. Escreva o teste da unidade antes da implementação. O domínio devolve `Either<Failure, T>`. A fonte de dados lança `ServerException` ou `CacheException`. O repositório traduz essas exceções. O bloc chama apenas casos de uso.

No `injection_container.dart`, registre a feature acima do bloco `Core`:

```dart
sl.registerFactory(() => CustomersBloc(getCustomers: sl()));
sl.registerLazySingleton(() => GetCustomers(sl()));
sl.registerLazySingleton<CustomersRepository>(
  () => CustomersRepositoryImpl(
    remoteDataSource: sl(),
    localDataSource: sl(),
    networkInfo: sl(),
  ),
);
```

`shared_preferences` guarda a sessão simulada. O SQLite guarda os clientes de desenvolvimento. `http` continua de fora até existir a fonte remota real.

## Dependências de arquitetura

| Pacote | Função |
| --- | --- |
| `equatable` 2.1.0 | Igualdade por valor. A versão 3.0.0 deixou de comparar `runtimeType` e faria `ServerFailure` e `CacheFailure` serem iguais. |
| `dartz` 0.10.1 | `Either`, `Left` e `Right`. Compatível com Dart 3. A última publicação é de 2021; o contrato foi mantido para não trocar o padrão do projeto de referência. |
| `get_it` | Service locator. |
| `flutter_bloc` 9.1.1 | Estado da presentation. A API usa `on<Event>`, não `mapEventToState`. |
| `shared_preferences` | Persistência da sessão simulada, atrás de `AuthLocalDataSource`. |
| `sqflite` | Banco local de clientes durante o desenvolvimento. Escolhido no lugar de Drift para não exigir geração de código, e no lugar de `shared_preferences` porque os clientes precisam de consulta, filtro, paginação e evolução de schema. |
| `bloc_test` | Testes do `AuthBloc`. |
| `internet_connection_checker_plus` | Substitui `data_connection_checker`, incompatível com Dart 3. |
| `mocktail` | Mocks de teste sem geração de código. Substitui o `mockito` 4, incompatível com null safety. |
| `speech_to_text` 7.5.0 | Reconhecimento de uma frase pelo sistema. Não grava áudio e não fica ligado em segundo plano. No Android costuma precisar de internet, salvo pacote de idioma instalado. No iOS, o modo no aparelho falha sem o modelo offline. Não há chave de serviço externo. |
| `flutter_tts` 4.2.5 | Leitura da resposta do assistente pela voz pt-BR instalada no aparelho. A leitura não inicia uma nova escuta. |
