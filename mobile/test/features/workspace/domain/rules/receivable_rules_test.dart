import 'package:flutter_test/flutter_test.dart';
import 'package:pouapp/features/workspace/domain/entities/receivable.dart';
import 'package:pouapp/features/workspace/domain/entities/street_ledger.dart';
import 'package:pouapp/features/workspace/domain/rules/receivable_rules.dart';

void main() {
  test('change is separate from the payment and is not credit', () {
    final plan = planReceipt(
      amountCents: 8000,
      tenderedCents: 10000,
      allowCredit: false,
      selected: const [
        Receivable(
          id: 'debt',
          customerId: 'ana',
          description: 'Saldo inicial',
          amountCents: 8000,
          openCents: 8000,
          occurredOn: '2026-11-03',
        ),
      ],
    );

    expect(plan.error, isNull);
    expect(plan.changeCents, 2000);
    expect(plan.creditCents, 0);
    expect(plan.allocatedCents, 8000);
  });

  test('excess stays out unless the user chooses credit', () {
    const debt = Receivable(
      id: 'debt',
      customerId: 'ana',
      description: 'Saldo inicial',
      amountCents: 8000,
      openCents: 8000,
      occurredOn: '2026-11-03',
    );
    final refused = planReceipt(
      amountCents: 10000,
      allowCredit: false,
      selected: const [debt],
    );
    final accepted = planReceipt(
      amountCents: 10000,
      allowCredit: true,
      selected: const [debt],
    );

    expect(refused.error, contains('crédito'));
    expect(accepted.creditCents, 2000);
    expect(accepted.allocatedCents, 8000);
  });

  test('a partial payment covers only part of the debt', () {
    final plan = planReceipt(
      amountCents: 5000,
      allowCredit: false,
      selected: const [
        Receivable(
          id: 'debt',
          customerId: 'ana',
          description: 'Saldo inicial',
          amountCents: 15000,
          openCents: 15000,
          occurredOn: '2026-11-03',
        ),
      ],
    );

    expect(plan.allocations.single.amountCents, 5000);
    expect(plan.creditCents, 0);
    expect(plan.changeCents, isNull);
  });

  test('whatsapp link keeps country code and encodes the message', () {
    expect(whatsAppDigits('011 98888-7777'), '5511988887777');
    expect(whatsAppDigits('5511988887777'), '5511988887777');
    expect(whatsAppDigits(null), isNull);
    expect(whatsAppDigits('000'), isNull);

    final uri = whatsAppChatUri(
      digits: '5511988887777',
      message: 'Olá, Ana! 😊\nMinha chave Pix:\n11988887777',
    );

    final app = whatsAppAppUri(
      digits: '5511988887777',
      message: 'Olá, Ana! 😊\nMinha chave Pix:\n11988887777',
    );
    expect(app.scheme, 'whatsapp');
    expect(app.host, 'send');
    expect(app.queryParameters['phone'], '5511988887777');
    expect(
      app.queryParameters['text'],
      'Olá, Ana! 😊\nMinha chave Pix:\n11988887777',
    );
    expect(app.toString(), isNot(contains('https')));

    expect(uri.scheme, 'https');
    expect(uri.host, 'wa.me');
    expect(uri.path, '/5511988887777');
    expect(uri.toString(), isNot(contains('+')));
    expect(
      uri.queryParameters['text'],
      'Olá, Ana! 😊\nMinha chave Pix:\n11988887777',
    );
  });

  test('pix profile accepts a key and rejects an empty one', () {
    expect(pixProfileProblem(const BusinessProfile()), isNotNull);
    expect(
      pixProfileProblem(
        const BusinessProfile(
          pixKeyType: PixKeyType.email,
          pixKey: 'ana@hortifruti.com',
          receiverName: 'Hortifruti da Ana',
        ),
      ),
      isNull,
    );
    expect(
      pixProfileProblem(
        const BusinessProfile(
          pixKeyType: PixKeyType.phone,
          pixKey: '11988887777',
          receiverName: 'Ana',
        ),
      ),
      isNull,
    );
  });

  test('mixed due dates do not become one date', () {
    expect(sharedDueDate(['2026-11-10', '2026-11-20']), isNull);
    expect(sharedDueDate(['2026-11-10', '2026-11-10']), '2026-11-10');
    expect(sharedDueDate([null, null]), isNull);

    final message = chargeMessage(
      customerName: 'Ana',
      description: chargeDescription(total: true, custom: false),
      amountCents: 10000,
      pixKey: '11988887777',
      receiverName: 'Hortifruti da Ana',
    );

    expect(message, contains('Olá, Ana! 😊'));
    expect(message, contains('O valor do saldo em aberto é de R\$ 100,00.'));
    expect(message, isNot(contains('Vencimento:')));
    expect(
      message,
      contains('Copie a chave Pix abaixo e cole no seu banco:\n\n11988887777'),
    );
    expect(message, contains('Recebedor: Hortifruti da Ana'));
    expect(message, isNot(contains('000201')));
  });

  test('a single note keeps its own due date and remaining value', () {
    final message = chargeMessage(
      customerName: 'Beatriz',
      description: chargeDescription(
        total: false,
        custom: false,
        receivableDescription: 'Saldo inicial',
      ),
      amountCents: 10000,
      dueOn: '2026-11-20',
      pixKey: 'beatriz@hortifruti.com',
      receiverName: 'Hortifruti da Ana',
    );

    expect(message, contains('restante de Saldo inicial'));
    expect(message, contains('R\$ 100,00'));
    expect(message, contains('Vencimento: 20/11/2026'));
  });

  test('a custom charge cannot pass the open balance', () {
    expect(
      chargeAmountProblem(amountCents: 10001, openCents: 10000),
      contains('saldo em aberto'),
    );
    expect(chargeAmountProblem(amountCents: 10000, openCents: 10000), isNull);
    expect(chargeDescription(total: false, custom: true), 'desta cobrança');
    expect(paymentMethodLabel(PaymentMethod.cash), 'Dinheiro');
    expect(paymentMethodLabel(PaymentMethod.pix), 'Pix');
    expect(chargeStatusLabel(ChargeStatus.prepared), 'Cobrança preparada');
    expect(chargeStatusLabel(ChargeStatus.whatsappOpened), 'WhatsApp aberto');
  });
}
