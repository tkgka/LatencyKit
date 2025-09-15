# LatencyKit

<img width="256" height="256" alt="image" src="https://github.com/user-attachments/assets/e52c331b-ba9f-4b1f-a7d9-8b740c670a22" />

LatencyKit is a toolkit for measuring network status by RTT (round-trip time) and throughput, to get an accurate assessment of whether the network can actually transmit data reliably under real conditions.

## Features
  - Measure RTT from requested URLSession.
  - Measure throughput from requested URLSession.
  - notify Latency State when value change(slow, medium, fast).

## Getting Started

```swift
import SwiftUI
import Combine
import LatencyKit

struct ContentView: View {
    
    @State var urlString = "" /// url to get response
    @State var numberOfRequest: Int = 1
        
    let model: Model = .init()
    let session: URLSession
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                TextField("url", text: $urlString, axis: .vertical)
                
                Text("NumberOfRequest")
                HStack {
                    Button {
                        numberOfRequest = max(numberOfRequest - 1, 1)
                    } label: {
                        Image(systemName: "arrow.left")
                    }
                    Text("\(numberOfRequest)")
                    Button {
                        numberOfRequest += 1
                    } label: {
                        Image(systemName: "arrow.right")
                    }
                }
            }
            .padding(.horizontal, 16)
            
            Button {
                guard let url = URL(string: urlString) else { return }
                Task {
                    await withTaskGroup { taskGroup in
                        for _ in 1...numberOfRequest {
                            taskGroup.addTask {
                                let task = session.dataTask(with: url)
                                task.resume()
                            }
                        }
                    }
                }
            } label: {
                Text("button")
            }
        }
    }
    
    init() {
        self.session = LKLatencyCheckSession.make(with: model.latencyChangePublisher)
        
    }  
}

final class Model: ObservableObject {

    let latencyChangePublisher = PassthroughSubject<LKStatus, Error>()
    var cancellable = Set<AnyCancellable>()
    
    init() {
        bind()
    }
    
    private func bind() {
        latencyChangePublisher
            .receive(on: DispatchQueue.main)
            .sink { error in
                print(error)
            } receiveValue: { output in
                print(output)
            }
            .store(in: &cancellable)
    }
}
```

---

this repo inspired by [this article](https://juejin.cn/post/7395080141129842697)
