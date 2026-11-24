Map<String, dynamic> catalogProduct({
  String id = 'product-1',
  String name = 'Producto de prueba',
  String? dose = '10 ml/L',
}) => {'id': id, 'name': name, 'recommended_dose': dose};

Map<String, dynamic> appliedProduct({
  String id = 'application-1',
  String productId = 'product-1',
  String area = 'Cocina',
  String? technique = 'aspersion',
  String info = 'Aplicación de prueba',
}) => {
  'id': id,
  'product_id': productId,
  'product_name': 'Producto de prueba',
  'area': area,
  'technique': technique,
  'applied_dose': '10 ml/L',
  'extra_info': info,
};

Map<String, dynamic> productsContext({
  List<Map<String, dynamic>> products = const [],
  List<Map<String, dynamic>>? options,
  bool withStation = false,
}) => {
  'visit_id': 'visit-0',
  'customer_name': 'Cliente de prueba',
  'location_name': 'Sucursal de prueba',
  'scheduled_time_start': '09:00:00',
  'service_price': '100.00',
  'stations': withStation
      ? [
          {
            'id': 'station-1',
            'internal_code': 'CB-001',
            'station_type_name': 'Estación de prueba',
            'findings': [
              {'id': 'finding-1', 'label': 'Sin actividad', 'severity': 0},
            ],
            'inspection': {
              'finding_id': 'finding-1',
              'station_condition': 'util',
              'pest_ids': [],
              'notes': 'Inspección existente',
            },
          },
        ]
      : [],
  'pests': [],
  'products': products,
  'product_options': options ?? [catalogProduct()],
};

List<Map<String, dynamic>> savedProductResponse(List<dynamic> submitted) => [
  for (var i = 0; i < submitted.length; i++)
    {
      ...(submitted[i] as Map<String, dynamic>),
      'id': 'application-$i',
      'product_name': 'Producto de prueba',
      'applied_dose': '10 ml/L',
    },
];
