public class SyntheticSchemaValueFactory {
  public static void populateCustomFields(
    SObject record,
    String runKey,
    Integer sequence
  ) {
    Map<String, Schema.SObjectField> fields = record.getSObjectType()
      .getDescribe()
      .fields
      .getMap();

    for (String fieldApiName : fields.keySet()) {
      Schema.DescribeFieldResult field = fields
        .get(fieldApiName)
        .getDescribe();
      if (
        !field.isCustom() ||
        !field.isCreateable() ||
        field.isCalculated() ||
        field.isAutoNumber() ||
        field.isDefaultedOnCreate() ||
        record.get(fieldApiName) != null
      ) {
        continue;
      }

      Object generatedValue = generateValue(field, fieldApiName, runKey, sequence);
      if (generatedValue != null) {
        record.put(fieldApiName, generatedValue);
      } else if (!field.isNillable()) {
        throw new SyntheticDataException(
          'Cannot synthesize required custom field ' +
          record.getSObjectType().getDescribe().getName() +
          '.' +
          fieldApiName +
          ' (' +
          String.valueOf(field.getType()) +
          '). Add an org-specific value in the relevant factory.'
        );
      } else if (sequence == 1) {
        System.debug(
          LoggingLevel.WARN,
          'Skipped unsupported optional custom field ' +
          record.getSObjectType().getDescribe().getName() +
          '.' +
          fieldApiName
        );
      }
    }
  }

  public static List<String> activePicklistValues(
    Schema.SObjectField fieldToken
  ) {
    List<String> values = new List<String>();
    for (
      Schema.PicklistEntry option : fieldToken
        .getDescribe()
        .getPicklistValues()
    ) {
      if (option.isActive()) {
        values.add(option.getValue());
      }
    }
    return values;
  }

  public static List<String> preferredActivePicklistValues(
    Schema.SObjectField fieldToken,
    List<String> preferredValues
  ) {
    List<String> activeValues = activePicklistValues(fieldToken);
    Map<String, String> activeByNormalizedValue = new Map<String, String>();
    for (String value : activeValues) {
      activeByNormalizedValue.put(value.toLowerCase(), value);
    }

    List<String> matches = new List<String>();
    for (String preferredValue : preferredValues) {
      String activeValue = activeByNormalizedValue.get(
        preferredValue.toLowerCase()
      );
      if (activeValue != null) {
        matches.add(activeValue);
      }
    }
    return matches.isEmpty() ? activeValues : matches;
  }

  private static Object generateValue(
    Schema.DescribeFieldResult field,
    String fieldApiName,
    String runKey,
    Integer sequence
  ) {
    Schema.DisplayType fieldType = field.getType();
    if (
      fieldType == Schema.DisplayType.Picklist ||
      fieldType == Schema.DisplayType.MultiPicklist
    ) {
      List<String> activeValues = new List<String>();
      for (Schema.PicklistEntry option : field.getPicklistValues()) {
        if (option.isActive()) {
          activeValues.add(option.getValue());
        }
      }
      return activeValues.isEmpty()
        ? null
        : activeValues[Math.mod(sequence - 1, activeValues.size())];
    }
    if (fieldType == Schema.DisplayType.Boolean) {
      return false;
    }
    if (fieldType == Schema.DisplayType.Date) {
      return Date.today().addDays(-Math.mod(sequence, 30));
    }
    if (fieldType == Schema.DisplayType.DateTime) {
      return Datetime.now().addDays(-Math.mod(sequence, 30));
    }
    if (fieldType == Schema.DisplayType.Time) {
      return Time.newInstance(9 + Math.mod(sequence, 8), 0, 0, 0);
    }
    if (fieldType == Schema.DisplayType.Integer) {
      return sequence;
    }
    if (fieldType == Schema.DisplayType.Long) {
      return Long.valueOf(String.valueOf(sequence));
    }
    if (
      fieldType == Schema.DisplayType.Currency ||
      fieldType == Schema.DisplayType.Double ||
      fieldType == Schema.DisplayType.Percent
    ) {
      return Decimal.valueOf(sequence);
    }
    if (fieldType == Schema.DisplayType.Email) {
      return 'synthetic+' + String.valueOf(sequence) + '@example.invalid';
    }
    if (fieldType == Schema.DisplayType.Phone) {
      return '+1 555 010 ' + String.valueOf(1000 + Math.mod(sequence, 9000));
    }
    if (fieldType == Schema.DisplayType.Url) {
      return 'https://example.invalid/synthetic/' + String.valueOf(sequence);
    }
    if (
      fieldType == Schema.DisplayType.String ||
      fieldType == Schema.DisplayType.TextArea ||
      fieldType == Schema.DisplayType.EncryptedString ||
      fieldType == Schema.DisplayType.ComboBox
    ) {
      String textValue =
        String.valueOf(sequence) + '-' + fieldApiName + '-' + runKey;
      Integer maximumLength = field.getLength();
      return maximumLength > 0 && textValue.length() > maximumLength
        ? textValue.substring(0, maximumLength)
        : textValue;
    }
    return null;
  }
}
