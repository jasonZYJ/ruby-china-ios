//
//  OAuth2.swift
//  ruby-china-ios
//
//  OAuth2 密码授权客户端，替代 Heimdallr
//

import Foundation
import SwiftyJSON

protocol OAuth2Delegate: AnyObject {
    func oauth2DidLoginSuccessed(_ accessToken: String)
    func oauth2DidLoginFailed(_ error: NSError)
}

/// Keychain 访问令牌存储
class OAuthAccessTokenKeychainStore {

    private let service: String
    private let account = "accessToken"

    init(service: String) {
        self.service = service
    }

    func saveAccessToken(_ token: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: token.data(using: .utf8)!,
        ]
        var status = SecItemCopyMatching(query as CFDictionary, nil)
        if status == errSecSuccess {
            status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        } else if status == errSecItemNotFound {
            var addQuery = query
            addQuery.merge(attributes) { (_, new) in new }
            status = SecItemAdd(addQuery as CFDictionary, nil)
        }
        if status != errSecSuccess {
            log.error(["Keychain save token failed", status])
        }
    }

    func retrieveAccessToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    func clearAccessToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

class OAuth2 {
    weak var delegate: OAuth2Delegate?

    var deviceToken: String? {
        didSet {
            submitDeviceToken()
        }
    }

    fileprivate let accessTokenStore: OAuthAccessTokenKeychainStore

    fileprivate(set) var accessToken: String? {
        get { return APIRequest.shared.accessToken }
        set { APIRequest.shared.accessToken = newValue }
    }

    fileprivate(set) var currentUser: User? {
        didSet {
            NotificationCenter.default.post(name: NSNotification.Name.userChanged, object: nil)
        }
    }

    fileprivate(set) var unreadNotificationCount: Int = 0 {
        didSet {
            if unreadNotificationCount != oldValue {
                NotificationCenter.default.post(name: NSNotification.Name.userUnreadNotificationChanged, object: nil)
            }
        }
    }

    static fileprivate let _shared = OAuth2()

    static var shared: OAuth2 {
        return _shared
    }

    init() {
        accessTokenStore = OAuthAccessTokenKeychainStore(service: "org.ruby-china.turbolinks-app.oauth")

        accessToken = accessTokenStore.retrieveAccessToken()
        if (accessToken != nil) {
            if let userData = UserDefaults.standard.data(forKey: "loginUserJSON") {
                do {
                    let jsonObject = try JSON(data: userData)
                    currentUser = User(json: jsonObject)
                    refreshUnreadNotifications()
                } catch {
                }
            }

            reloadCurrentUser()
        }
    }

    /// 请求 OAuth2 密码授权令牌（替代 Heimdallr.requestAccessToken）
    func requestAccessToken(username: String, password: String, completion: @escaping (Result<String, NSError>) -> Void) {
        let parameters: [String: AnyObject] = [
            "grant_type": "password" as AnyObject,
            "client_id": OAUTH_CLIENT_ID as AnyObject,
            "client_secret": OAUTH_SECRET as AnyObject,
            "username": username as AnyObject,
            "password": password as AnyObject,
        ]

        guard let url = URL(string: "\(ROOT_URL)/oauth/token") else {
            completion(.failure(NSError(domain: "customize", code: -1, userInfo: [NSLocalizedDescriptionKey: "invalid oauth token url"])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = formURLEncode(parameters).data(using: .utf8)

        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            DispatchQueue.main.async {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                if let error = error {
                    completion(.failure(error as NSError))
                    return
                }

                guard let data = data, let json = try? JSON(data: data) else {
                    let err = NSError(domain: "customize", code: -1, userInfo: [NSLocalizedDescriptionKey: "get accessToken failed".localized])
                    completion(.failure(err))
                    return
                }

                if statusCode == 200, let token = json["access_token"].string {
                    self.accessTokenStore.saveAccessToken(token)
                    completion(.success(token))
                } else if statusCode == 400 || statusCode == 401 {
                    // 与 Heimdallr 的 invalidCredentials 错误码保持一致（登录页依赖 code == 3 显示提示）
                    let err = NSError(domain: "HeimdallrErrorDomain", code: 3, userInfo: [
                        NSLocalizedDescriptionKey: json["error_description"].string ?? "login error message".localized,
                    ])
                    completion(.failure(err))
                } else {
                    let err = NSError(domain: "customize", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "get accessToken failed".localized])
                    completion(.failure(err))
                }
            }
        }
        task.resume()
    }

    func login(_ username: String, password: String) {
        requestAccessToken(username: username, password: password) { result in
            switch result {
            case .success(let token):
                let accessToken = token
                log.info("Login successed. accessToken=\(accessToken)")
                self.accessToken = accessToken
                self.submitDeviceToken()
                self.reloadCurrentUser() { (response, user) in
                    switch response.result {
                    case .success(_):
                        if user != nil {
                            self.delegate?.oauth2DidLoginSuccessed(accessToken)
                        } else {
                            self.delegate?.oauth2DidLoginFailed(NSError(domain: "customize", code: -1, userInfo: [NSLocalizedDescriptionKey: "no user information was returned".localized]))
                        }
                    case .failure(let err):
                        self.delegate?.oauth2DidLoginFailed(err as NSError)
                    }
                }
            case .failure(let err):
                DispatchQueue.main.async {
                    self.delegate?.oauth2DidLoginFailed(err)
                }
            }
        }
    }

    var isLogined: Bool {
        return accessToken != nil && currentUser != nil
    }

    fileprivate func submitDeviceToken() {
        if let deviceToken = deviceToken , isLogined {
            DeviseService.create(deviceToken)
        }
    }

    fileprivate func reloadCurrentUser(callback: ((APICallbackResponse, User?) -> ())? = nil) {
        UsersService.me { (response, user) in
            switch response.result {
            case .success(let data) where user != nil:
                self.currentUser = user!
                log.info(self.currentUser)
                UserDefaults.standard.setValue(data, forKey: "loginUserJSON")
                UserDefaults.standard.synchronize()
            default:
                break
            }
            callback?(response, user)
        }
    }

    func refreshUnreadNotifications() {
        if !isLogined {
            unreadNotificationCount = 0
            return
        }
        APIRequest.shared.get("/api/v3/notifications/unread_count", parameters: nil) { [weak self] (response, result) in
            if let result = result, !result.isEmpty {
                let unreadCount = result["count"].intValue
                log.info(["Unread notification count", unreadCount])
                self?.unreadNotificationCount = unreadCount
            }
        }
    }

    func logout() {
        if let deviceToken = deviceToken , isLogined {
            DeviseService.destroy(deviceToken)
        }

        accessTokenStore.clearAccessToken()
        accessToken = nil
        currentUser = nil
        unreadNotificationCount = 0
        UserDefaults.standard.removeObject(forKey: "loginUserJSON")
        UserDefaults.standard.synchronize()

        NotificationCenter.default.post(name: NSNotification.Name.userSignout, object: nil)
    }

    fileprivate func formURLEncode(_ parameters: [String: AnyObject]) -> String {
        var components = URLComponents()
        components.queryItems = parameters.map { key, value in
            URLQueryItem(name: key, value: "\(value)")
        }
        return components.percentEncodedQuery ?? ""
    }
}
