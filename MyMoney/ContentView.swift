//
//  ContentView.swift
//  MyMoney
//
//  Created by Ronak Punase on 03/08/25.
//

import SwiftUI

struct ContentView: View {
    @State private var pdfManager = PdfManager()
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            VStack {
                if pdfManager.isProcessing {
                    ProgressView("Processing PDF...")
                        .padding()
                } else {
                    TabView(selection: $selectedTab) {
                        TransactionsView(transactions: pdfManager.transactions)
                            .tabItem {
                                Image(systemName: "list.bullet")
                                Text("Transactions")
                            }
                            .tag(0)
                        
                        StatisticsView(transactions: pdfManager.transactions)
                            .tabItem {
                                Image(systemName: "chart.bar.fill")
                                Text("Statistics")
                            }
                            .tag(1)
                        
                        DebugView(text: pdfManager.rawText)
                            .tabItem {
                                Image(systemName: "doc.text")
                                Text("Raw Text")
                            }
                            .tag(2)
                    }
                }
            }
            .navigationTitle("PDF Data Extractor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Extract") {
                        pdfManager.extractDataFromPDF()
                    }
                    .disabled(pdfManager.isProcessing)
                }
            }
            .alert("Password Required", isPresented: $pdfManager.showPasswordAlert) {
                SecureField("Enter PDF password", text: $pdfManager.passwordInput)
                Button("Unlock") {
                    pdfManager.unlockWithPassword()
                }
                Button("Cancel", role: .cancel) {
                    pdfManager.cancelPasswordPrompt()
                }
            } message: {
                Text("This PDF is password protected.")
            }
            .alert("Error", isPresented: $pdfManager.showErrorAlert) {
                Button("OK") { }
            } message: {
                Text(pdfManager.errorMessage)
            }
        }
    }
}


#Preview {
    ContentView()
}
