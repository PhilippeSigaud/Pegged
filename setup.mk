DFILES := ${shell find pegged -name "*.d" -not \( -path "*dev*" -o -path "*tester*"  -o -path "*performancetest*" -o -path "*tohtml.d" \) }
