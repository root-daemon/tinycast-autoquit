import Foundation
import Security

/// Proves a staged bundle carries the same signing certificate as this fork.
enum BundleSignature {
    /// Returned so the swap at quit can pin the verified bytes; a release key never widens trust.
    static func trustedHash(of bundleURL: URL, releaseSigned _: Bool) -> Data? {
        var staticCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(bundleURL as CFURL, [], &staticCode) == errSecSuccess,
            let staticCode,
            SecStaticCodeCheckValidity(staticCode, flags, nil) == errSecSuccess,
            let running = runningLeaf(), let candidate = leaf(of: staticCode), running == candidate
        else { return nil }
        return uniqueHash(of: staticCode)
    }

    /// An unsealed bundle can claim any identity, and a nested helper is where one hides.
    private static let flags = SecCSFlags(
        rawValue: kSecCSCheckAllArchitectures | kSecCSCheckNestedCode | kSecCSStrictValidate)

    private static func runningLeaf() -> Data? {
        var code: SecCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code else { return nil }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode else {
            return nil
        }
        return leaf(of: staticCode)
    }

    private static func leaf(of code: SecStaticCode) -> Data? {
        guard let certificates = signingInformation(of: code)?[kSecCodeInfoCertificates as String]
            as? [SecCertificate],
            let leaf = certificates.first
        else { return nil }
        return SecCertificateCopyData(leaf) as Data
    }

    private static func uniqueHash(of code: SecStaticCode) -> Data? {
        signingInformation(of: code)?[kSecCodeInfoUnique as String] as? Data
    }

    private static func signingInformation(of code: SecStaticCode) -> [String: Any]? {
        var information: CFDictionary?
        let options = SecCSFlags(rawValue: kSecCSSigningInformation)
        guard SecCodeCopySigningInformation(code, options, &information) == errSecSuccess else {
            return nil
        }
        return information as? [String: Any]
    }
}
