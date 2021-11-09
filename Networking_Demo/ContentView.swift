//
//  ContentView.swift
//  Networking_Demo
//
//  Created by Maksim Tochilkin on 11/8/21.
//

import SwiftUI
import Combine

struct Meme: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let url: URL
    let rating: Int
    
    enum CodingKeys: String, CodingKey {
        case id, title = "name", url, rating
    }
    
//    init(from decoder: Decoder) throws {
//        let containder = try decoder.container(keyedBy: CodingKeys.self)
//        self.id = try containder.decodeIfPresent(String.self, forKey: .id) ?? "N/A"
//        self.title = try containder.decodeIfPresent(String.self, forKey: .title) ?? "N/A"
//        self.url = try containder.decodeIfPresent(URL.self, forKey: .url) ?? URL(string: "www.google.com")!
//        self.rating = try containder.decodeIfPresent(Int.self, forKey: .rating) ?? 5
//    }
}

struct MemesArray: Codable {
    let memes: [Meme]
}

final class MemeAPIManager {
    private let url = URL(string: "https://api.imgflip.com/get_memes")!
    
    struct APIResponse: Codable {
        let success: Bool
        let data: MemesArray
    }
    
    func loadMemes(_ handler: @escaping ([Meme]) -> Void) {
        let request = URLRequest(url: url)

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data else { return }
            
            do {
                let decodedResponse = try JSONDecoder().decode(APIResponse.self, from: data)
                handler(decodedResponse.data.memes)
            } catch DecodingError.keyNotFound(let key, let context) {
                print("Failed to decode due to missing key '\(key.stringValue)' not found – \(context.debugDescription)")
            } catch DecodingError.typeMismatch(_, let context) {
                print("Failed to decode due to type mismatch – \(context.debugDescription)")
            } catch DecodingError.valueNotFound(let type, let context) {
                print("Failed to decode due to missing \(type) value – \(context.debugDescription)")
            } catch DecodingError.dataCorrupted(_) {
                print("Failed to decode because it appears to be invalid JSON")
            } catch {
                print("Failed to decode: \(error.localizedDescription)")
            }
        }
        
        task.resume()
    }

}

final class MemeViewModel: ObservableObject {
    let memeManager = MemeAPIManager()
    @Published var memes: [Meme] = []
    
    
    private var imageCache: [Meme: UIImage] = [:]
    
    init() {
        memeManager.loadMemes { [weak self] memes in
            DispatchQueue.main.async {
                self?.memes = memes
            }
        }
    }
    
    
    func image(for meme: Meme) -> AnyPublisher<UIImage?, Never> {
        if let image = imageCache[meme] {
            return Just(image).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: meme.url)
            .map { output in
                sleep(1)
                let image = UIImage(data: output.data)
                self.imageCache[meme] = image
                return image
            }
            .replaceError(with: UIImage())
            .eraseToAnyPublisher()
    }
    
    func asyncImage(for meme: Meme) async throws -> UIImage? {
        print("before initing child task")
        async let (data, _) = URLSession.shared.data(for: URLRequest(url: meme.url))
        print("Hey I am doing work while URLSession is fetching the image")
        
        return try await UIImage(data: data)
    }
}

struct ContentView: View {
    @StateObject var viewModel = MemeViewModel()
    
    var body: some View {
        NavigationView {
            List(viewModel.memes) { meme in
                NavigationLink(meme.title) {
                    ImageView(viewModel: viewModel, meme: meme)
                }
            }
            .navigationTitle("Memes")
        }
    }
}

struct ImageView: View {
    @State private var uiImage: UIImage?
    @ObservedObject var viewModel: MemeViewModel
    
    let meme: Meme

    var body: some View {
        ZStack {
            if let uiImage = uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                ProgressView()
            }
        }.onAppear {
            Task {
                let image = try await viewModel.asyncImage(for: meme)
                self.uiImage = image
            }
        }
//        .onReceive(viewModel.image(for: meme).receive(on: DispatchQueue.main)) { res in
//            Task {
//
//            }
//            self.uiImage = res
//        }
    }
}



struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
