//
//  Request.swift
//  ruby-china-ios
//
//  Created by Jason Lee on 16/7/26.
//  Copyright © 2016年 ruby-china. All rights reserved.
//
//  基于 URLSession 的网络层，替代 Alamofire
//

import Foundation
import SwiftyJSON

/// 与原 Alamofire DataResponse<Data> 字段保持兼容的响应封装
struct APIResponse {
    let request: URLRequest?
    let response: HTTPURLResponse?
    let data: Data?
    let result: Result<Data, Error>
}

typealias APICallbackResponse = APIResponse
typealias APICallback = (APICallbackResponse, JSON?) -> Void

class APIRequest {

    static fileprivate var _shared = APIRequest()

    static var shared: APIRequest {
        return _shared
    }

    fileprivate lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 15
        configuration.httpAdditionalHeaders = [
            "Accept": "application/json",
            "User-Agent": USER_AGENT,
        ]
        return URLSession(configuration: configuration)
    }()

    var accessToken: String?

    fileprivate func _request(_ method: String, path: String, parameters: [String: AnyObject]?, callback: @escaping APICallback) {
        let urlString = "\(ROOT_URL)\(path)"
        var request = URLRequest(url: URL(string: urlString)!)
        request.httpMethod = method

        if let parameters = parameters {
            let query = encodeParameters(parameters)
            if method == "GET" || method == "DELETE" {
                if var components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false), !query.isEmpty {
                    components.percentEncodedQuery = query
                    request.url = components.url
                }
            } else {
                request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
                request.httpBody = query.data(using: .utf8)
            }
        }

        if let accessToken = accessToken, urlString.hasPrefix(ROOT_URL) {
            request.setValue("Bearer " + accessToken, forHTTPHeaderField: "Authorization")
        }

        let task = session.dataTask(with: request) { (data, response, error) in
            DispatchQueue.main.async {
                let httpResponse = response as? HTTPURLResponse

                if let error = error {
                    log.error([method, path, error])
                    let apiResponse = APIResponse(request: request, response: httpResponse, data: data, result: .failure(error))
                    callback(apiResponse, nil)
                    return
                }

                let statusCode = httpResponse?.statusCode ?? 0
                log.debug([method, path, statusCode])
                if statusCode == 401 {
                    OAuth2.shared.logout()
                    return
                }

                var result: JSON? = nil
                if let data = data {
                    do {
                        try result = JSON(data: data)
                    } catch {}
                }
                let apiResponse = APIResponse(request: request, response: httpResponse, data: data, result: .success(data ?? Data()))
                callback(apiResponse, result)
            }
        }
        task.resume()
    }

    fileprivate func encodeParameters(_ parameters: [String: AnyObject]) -> String {
        var components = URLComponents()
        var queryItems = [URLQueryItem]()
        for (key, value) in parameters {
            let valueString: String
            switch value {
            case let number as NSNumber:
                valueString = number.stringValue
            case let boolean as Bool:
                valueString = boolean ? "true" : "false"
            default:
                valueString = "\(value)"
            }
            queryItems.append(URLQueryItem(name: key, value: valueString))
        }
        components.queryItems = queryItems
        return components.percentEncodedQuery ?? ""
    }

    func post(_ path: String, parameters: [String: AnyObject]?, callback: @escaping APICallback) {
        return _request("POST", path: path, parameters: parameters, callback: callback)
    }

    func get(_ path: String, parameters: [String: AnyObject]?, callback: @escaping APICallback) {
        return _request("GET", path: path, parameters: parameters, callback: callback)
    }

    func delete(_ path: String, parameters: [String: AnyObject]?, callback: @escaping APICallback) {
        return _request("DELETE", path: path, parameters: parameters, callback: callback)
    }
}
