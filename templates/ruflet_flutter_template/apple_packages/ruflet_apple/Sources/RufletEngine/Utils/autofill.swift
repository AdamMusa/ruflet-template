enum RufletAutofillContextAction: String, CaseIterable, RufletStringEnum {
    case commit, cancel
}

private let rufletAutofillHints: [String: String] = {
    let names = [
        "addressCity", "addressCityAndState", "addressState", "birthday", "birthdayDay",
        "birthdayMonth", "birthdayYear", "countryCode", "countryName",
        "creditCardExpirationDate", "creditCardExpirationDay", "creditCardExpirationMonth",
        "creditCardExpirationYear", "creditCardFamilyName", "creditCardGivenName",
        "creditCardMiddleName", "creditCardName", "creditCardNumber", "creditCardSecurityCode",
        "creditCardType", "email", "familyName", "fullStreetAddress", "gender", "givenName",
        "impp", "jobTitle", "language", "location", "middleInitial", "middleName", "name",
        "namePrefix", "nameSuffix", "newPassword", "newUsername", "nickname", "oneTimeCode",
        "organizationName", "password", "photo", "postalAddress", "postalAddressExtended",
        "postalAddressExtendedPostalCode", "postalCode", "streetAddressLevel1",
        "streetAddressLevel2", "streetAddressLevel3", "streetAddressLevel4",
        "streetAddressLine1", "streetAddressLine2", "streetAddressLine3", "sublocality",
        "telephoneNumber", "telephoneNumberAreaCode", "telephoneNumberCountryCode",
        "telephoneNumberDevice", "telephoneNumberExtension", "telephoneNumberLocal",
        "telephoneNumberLocalPrefix", "telephoneNumberLocalSuffix", "telephoneNumberNational",
        "transactionAmount", "transactionCurrency", "url", "username"
    ]
    return Dictionary(uniqueKeysWithValues: names.map { ($0.lowercased(), $0) })
}()

func parseAutofillHint(_ value: String?, _ defaultValue: String? = nil) -> String? {
    guard let value else { return defaultValue }
    return rufletAutofillHints[value.lowercased()] ?? defaultValue
}

func parseAutofillHints(_ value: Any?, _ defaultValue: [String]? = nil) -> [String]? {
    if let values = value as? [Any] {
        return values.compactMap { parseAutofillHint(String(describing: $0)) }
    }
    if let value = value as? String {
        return parseAutofillHint(value).map { [$0] } ?? []
    }
    return defaultValue
}

func parseAutofillContextAction(
    _ value: String?,
    _ defaultValue: RufletAutofillContextAction? = nil
) -> RufletAutofillContextAction? {
    parseEnum(RufletAutofillContextAction.self, value, defaultValue)
}
