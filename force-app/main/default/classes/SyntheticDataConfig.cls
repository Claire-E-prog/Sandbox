public class SyntheticDataConfig {
  public Integer accountCount = 20;
  public Integer contactsPerAccount = 2;
  public Integer opportunitiesPerAccount = 3;
  public Integer leadCount = 20;
  public Integer taskCount = 40;
  public Integer eventCount = 20;

  public List<String> ownerUsernames = new List<String>();
  public String runKey;

  // Scenario values are deliberately centralized here. Replace these lists or
  // construct a different config without changing any factory implementation.
  public List<String> companyNames = new List<String>{
    'Apex Precision Works',
    'Blue River Fabrication',
    'Continental Machine Systems',
    'Evergreen Industrial Components',
    'ForgeLine Manufacturing',
    'Great Lakes Robotics',
    'Ironclad Process Equipment',
    'Northstar Assembly Solutions',
    'Pioneer Motion Controls',
    'Summit Metal Products'
  };
  public List<String> cities = new List<String>{
    'Detroit',
    'Cleveland',
    'Milwaukee',
    'Pittsburgh',
    'Indianapolis'
  };
  public List<String> preferredIndustries = new List<String>{
    'Manufacturing',
    'Industrial Engineering',
    'Automotive',
    'Energy'
  };
  public List<String> contactTitles = new List<String>{
    'Plant Manager',
    'Procurement Director',
    'Operations Engineer',
    'Maintenance Manager'
  };
  public List<String> opportunityThemes = new List<String>{
    'Production Line Modernization',
    'Preventive Maintenance Program',
    'Automation Expansion',
    'Replacement Parts Agreement',
    'Plant Capacity Upgrade'
  };
  public List<String> preferredTaskSubjects = new List<String>{
    'Call',
    'Send Quote',
    'Follow Up',
    'Other'
  };
  public List<String> preferredEventSubjects = new List<String>{
    'Meeting',
    'Demo',
    'Site Visit'
  };

  public Decimal minimumAnnualRevenue = 5000000;
  public Decimal annualRevenueStep = 1750000;
  public Integer minimumEmployees = 75;
  public Integer employeeStep = 23;
  public Integer minimumOpportunityQuantity = 2;
  public Integer maximumOpportunityQuantity = 12;
  public Integer minimumSalesCycleDays = 30;
  public Integer maximumSalesCycleDays = 150;

  public List<ProductDefinition> products = new List<ProductDefinition>{
    new ProductDefinition('Industrial Servo Controller', 'MFG-SERVO-100', 4800),
    new ProductDefinition('High-Torque Conveyor Drive', 'MFG-DRIVE-220', 7250),
    new ProductDefinition(
      'Predictive Maintenance Sensor Kit',
      'MFG-SENSOR-310',
      1850
    ),
    new ProductDefinition(
      'Automated Inspection Cell',
      'MFG-INSPECT-400',
      28500
    ),
    new ProductDefinition('Hydraulic Pump Assembly', 'MFG-PUMP-510', 3900)
  };

  public static SyntheticDataConfig manufacturing() {
    return new SyntheticDataConfig();
  }

  public void validate() {
    if (ownerUsernames == null || ownerUsernames.isEmpty()) {
      throw new SyntheticDataException(
        'Add at least one Salesforce username to ownerUsernames.'
      );
    }
    if (
      accountCount == null ||
      contactsPerAccount == null ||
      opportunitiesPerAccount == null ||
      leadCount == null ||
      taskCount == null ||
      eventCount == null ||
      accountCount < 0 ||
      contactsPerAccount < 0 ||
      opportunitiesPerAccount < 0 ||
      leadCount < 0 ||
      taskCount < 0 ||
      eventCount < 0
    ) {
      throw new SyntheticDataException(
        'Record counts are required and cannot be negative.'
      );
    }
    if (
      companyNames == null ||
      cities == null ||
      preferredIndustries == null ||
      contactTitles == null ||
      opportunityThemes == null ||
      preferredTaskSubjects == null ||
      preferredEventSubjects == null ||
      products == null
    ) {
      throw new SyntheticDataException('Scenario collections cannot be null.');
    }
    if ((accountCount > 0 || leadCount > 0) && companyNames.isEmpty()) {
      throw new SyntheticDataException(
        'Account and Lead generation requires a company name.'
      );
    }
    if (
      minimumAnnualRevenue == null ||
      annualRevenueStep == null ||
      minimumEmployees == null ||
      employeeStep == null ||
      minimumOpportunityQuantity == null ||
      maximumOpportunityQuantity == null ||
      minimumSalesCycleDays == null ||
      maximumSalesCycleDays == null ||
      minimumOpportunityQuantity < 1 ||
      maximumOpportunityQuantity < minimumOpportunityQuantity
    ) {
      throw new SyntheticDataException(
        'Opportunity quantity range is invalid.'
      );
    }
    if (maximumSalesCycleDays < minimumSalesCycleDays) {
      throw new SyntheticDataException('Sales cycle range is invalid.');
    }

    for (ProductDefinition product : products) {
      if (
        product == null ||
        String.isBlank(product.name) ||
        String.isBlank(product.productCode) ||
        product.name.length() > 200 ||
        product.productCode.length() > 200 ||
        product.unitPrice == null ||
        product.unitPrice <= 0
      ) {
        throw new SyntheticDataException(
          'Every product needs a name and product code of 200 characters or fewer, plus a positive unit price.'
        );
      }
    }

    Integer opportunityCount = accountCount * opportunitiesPerAccount;
    Integer estimatedRows =
      accountCount +
      (accountCount * contactsPerAccount) +
      leadCount +
      (products.size() * 2) +
      (opportunityCount * 2) +
      taskCount +
      eventCount;
    if (estimatedRows > 9000) {
      throw new SyntheticDataException(
        'This synchronous run would create approximately ' +
          estimatedRows +
          ' rows. Keep it at or below 9,000 or use Batch Apex.'
      );
    }
  }

  public class ProductDefinition {
    public String name;
    public String productCode;
    public Decimal unitPrice;

    public ProductDefinition(
      String name,
      String productCode,
      Decimal unitPrice
    ) {
      this.name = name;
      this.productCode = productCode;
      this.unitPrice = unitPrice;
    }
  }
}
