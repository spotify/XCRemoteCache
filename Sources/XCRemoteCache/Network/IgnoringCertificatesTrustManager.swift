//
//  IgnoringCertificatesTrustManager.swift
//  
//
//  Created by Alexandr on 13.01.2022.
//

import Foundation

final class IgnoringCertificatesTrustManager: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard let serverTrust = challenge.protectionSpace.serverTrust else { return }
        
        let urlCredential = URLCredential(trust: serverTrust)
        completionHandler(.useCredential, urlCredential)
    }
}
