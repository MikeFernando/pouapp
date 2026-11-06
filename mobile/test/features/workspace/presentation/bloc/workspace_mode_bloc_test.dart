import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pouapp/core/error/failures.dart';
import 'package:pouapp/core/usecases/usecase.dart';
import 'package:pouapp/features/workspace/domain/entities/workspace_mode.dart';
import 'package:pouapp/features/workspace/domain/usecases/workspace_use_cases.dart';
import 'package:pouapp/features/workspace/presentation/bloc/workspace_mode_bloc.dart';

class MockGetWorkspaceMode extends Mock implements GetWorkspaceMode {}

class MockSaveWorkspaceMode extends Mock implements SaveWorkspaceMode {}

void main() {
  late MockGetWorkspaceMode mockGetMode;
  late MockSaveWorkspaceMode mockSaveMode;

  setUpAll(() {
    registerFallbackValue(const NoParams());
    registerFallbackValue(WorkspaceMode.rua);
  });

  setUp(() {
    mockGetMode = MockGetWorkspaceMode();
    mockSaveMode = MockSaveWorkspaceMode();
  });

  WorkspaceModeBloc buildBloc() {
    return WorkspaceModeBloc(getMode: mockGetMode, saveMode: mockSaveMode);
  }

  blocTest<WorkspaceModeBloc, WorkspaceModeState>(
    'should emit the stored mode',
    build: buildBloc,
    setUp: () {
      when(() => mockGetMode(any()))
          .thenAnswer((_) async => const Right(WorkspaceMode.gestao));
    },
    act: (bloc) => bloc.add(const WorkspaceModeRequested()),
    expect: () => const <WorkspaceModeState>[
      WorkspaceModeState(
        status: WorkspaceModeStatus.ready,
        mode: WorkspaceMode.gestao,
      ),
    ],
  );

  blocTest<WorkspaceModeBloc, WorkspaceModeState>(
    'should keep the previous mode when saving fails',
    build: buildBloc,
    seed: () => const WorkspaceModeState(
      status: WorkspaceModeStatus.ready,
      mode: WorkspaceMode.rua,
    ),
    setUp: () {
      when(() => mockSaveMode(any()))
          .thenAnswer((_) async => const Left(CacheFailure()));
    },
    act: (bloc) => bloc.add(const WorkspaceModeSelected(WorkspaceMode.gestao)),
    expect: () => const <WorkspaceModeState>[
      WorkspaceModeState(
        status: WorkspaceModeStatus.ready,
        mode: WorkspaceMode.gestao,
      ),
      WorkspaceModeState(
        status: WorkspaceModeStatus.ready,
        mode: WorkspaceMode.rua,
        message: 'Não foi possível ler o modo salvo neste aparelho.',
      ),
    ],
  );

  blocTest<WorkspaceModeBloc, WorkspaceModeState>(
    'should ignore a repeated selection',
    build: buildBloc,
    seed: () => const WorkspaceModeState(
      status: WorkspaceModeStatus.ready,
      mode: WorkspaceMode.rua,
    ),
    act: (bloc) => bloc.add(const WorkspaceModeSelected(WorkspaceMode.rua)),
    expect: () => const <WorkspaceModeState>[],
  );
}
