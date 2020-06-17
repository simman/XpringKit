import Foundation

/// Implements interaction with a PayID service.
/// - Warning:  This class is experimental and should not be used in production applications.
public class PayIDClient {
  private enum Headers {
    public enum Keys {
      public static let accept = "Accept"
      public static let payIDVersion = "PayID-Version"
    }

    public enum Values {
      public static let version = "1.0"
    }
  }

  /// The network this PayID client resolves on.
  private let network: String

  /// Initialize a new PayID client.
  ///
  /// - Warning: This initializer is deprecated. `PayIDClient`s will not be bound to a network in the future.
  ///
  /// - Parameter network: The network that addresses will be resolved on.
  ///
  /// - Note: Networks in this constructor take the form of an asset and an optional network (<asset>-<network>).
  /// For instance:
  ///   - xrpl-testnet
  ///   - xrpl-mainnet
  ///   - eth-rinkeby
  ///   - ach
  ///
  //  TODO: Link a canonical list at payid.org when available.
  @available(*, deprecated, message: "Use `init` instead.")
  public init(network: String) {
    self.network = network
  }

  /// Initialize a new PayID client.
  ///
  /// - Note: Networks in this constructor take the form of an asset and an optional network (<asset>-<network>).
  /// For instance:
  ///   - xrpl-testnet
  ///   - xrpl-mainnet
  ///   - eth-rinkeby
  ///   - ach
  ///
  //  TODO: Link a canonical list at payid.org when available.
  public init() {
    // Stub out the network parameter with an empty string to avoid having to use an optional.
    // TODO(keefertaylor): Remove this and the `network` iVar when deprecated methods are removed.
    self.network = ""
  }

  /// Resolve the given PayID to an address.
  ///
  /// - Parameter payID: The PayID to resolve for an address.
  /// - Parameter completion: A closure called with the result of the operation.
  /// - Returns: An address representing the given PayID.
  // TODO(keefertaylor): Make this API synchronous to mirror functionality provided by ILP / XRP.
  @available(*, deprecated, message: "Use `address(for:on:completion)` instead.")
  public func address(
    for payID: String,
    completion: @escaping (Result<CryptoAddressDetails, PayIDError>) -> Void
  ) {
    // Pass through to the non-deprecated method using the iVar.
    address(for: payID, on: self.network, completion: completion)
  }

  /// Resolve the given PayID to an address on the given network.
  ///
  /// - Parameter payID: The PayID to resolve for an address.
  /// - Parameter network: The network to resolve on.
  /// - Parameter completion: A closure called with the result of the operation.
  /// - Returns: An address representing the given PayID.
  // TODO(keefertaylor): Make this API synchronous to mirror functionality provided by ILP / XRP.
  public func address(
    for payID: String,
    on network: String,
    completion: @escaping (Result<CryptoAddressDetails, PayIDError>) -> Void
  ) {
    guard let payIDComponents = PayIDUtils.parse(payID: payID) else {
      return completion(.failure(.invalidPayID(payID: payID)))
    }
    let host = payIDComponents.host
    // Drop the leading '/' in the path, Swagger adds it for us.
    let path = String(payIDComponents.path.dropFirst())

    let acceptHeaderValue = "application/\(self.network)+json"
    let client = APIClient(baseURL: "https://" + host)
    client.defaultHeaders = [
      Headers.Keys.accept: acceptHeaderValue,
      Headers.Keys.payIDVersion: Headers.Values.version
    ]

    let request = API.ResolvePayID.Request(path: path)

    client.makeRequest(request) { apiResponse in
      switch apiResponse.result {
      case .success(let response):
        switch response {
        case .status200(let paymentInformation):
          // With a specific network, exactly one address should be returned by a PayId lookup.
          guard paymentInformation.addresses.count == 1 else {
            let unexpectedResponseError = PayIDError.unexpectedResponse
            completion(.failure(unexpectedResponseError))
            return
          }
          completion(.success(paymentInformation.addresses[0].addressDetails))
        case .status404:
          completion(.failure(.mappingNotFound(payID: payID, network: self.network)))
        case .status415, .status503:
          completion(.failure(.unexpectedResponse))
        }

      case .failure(let error):
        completion(.failure(.unknown(error: "Unknown error making request: \(error)")))
      }
    }
  }
}
