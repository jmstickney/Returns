//
//  ImageManager.swift
//  Returns
//
//  Created by Jonathan Stickney on 3/28/25.
//


import Foundation
import SwiftUI
import UIKit

class ImageManager {
    static let shared = ImageManager()
    
    private let fileManager = FileManager.default
    private let documentsDirectory: URL
    
    private init() {
        documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    // Save image and return identifier
    func saveImage(_ image: UIImage, withID id: UUID? = nil) -> UUID {
        let imageID = id ?? UUID()
        let imageData = image.jpegData(compressionQuality: 0.8)
        let imagePath = documentsDirectory.appendingPathComponent("\(imageID.uuidString).jpg")
        
        do {
            try imageData?.write(to: imagePath)
        } catch {
            print("Error saving image: \(error)")
        }
        
        return imageID
    }
    
    // Load image from identifier
    func loadImage(withID id: UUID?) -> UIImage? {
        guard let id = id else { return nil }
        
        let imagePath = documentsDirectory.appendingPathComponent("\(id.uuidString).jpg")
        
        do {
            let imageData = try Data(contentsOf: imagePath)
            return UIImage(data: imageData)
        } catch {
            print("Error loading image: \(error)")
            return nil
        }
    }
    
    // Delete image
    func deleteImage(withID id: UUID?) {
        guard let id = id else { return }
        
        let imagePath = documentsDirectory.appendingPathComponent("\(id.uuidString).jpg")
        
        do {
            try fileManager.removeItem(at: imagePath)
        } catch {
            print("Error deleting image: \(error)")
        }
    }
}