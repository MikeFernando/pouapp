abstract final class CustomerRoutes {
  static const home = '/';
  static const customers = '/customers';
  static const create = '/customers/new';

  static String details(String id) => '/customers/$id';

  static String edit(String id) => '/customers/$id/edit';
}
