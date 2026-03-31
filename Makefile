# Chiaki Apple - Build System
#
# Usage:
#   make              - Build all xcframeworks
#   make frameworks   - Same as above
#   make mbedtls      - Build mbedtls xcframeworks only
#   make opus         - Build opus xcframework only
#   make libchiaki    - Build libchiaki xcframework only
#   make clean        - Remove all build artifacts
#   make clean-build  - Remove build cache only (keep xcframeworks)
#   make help         - Show this help

.PHONY: all frameworks mbedtls opus libchiaki libplacebo clean clean-build setup help

# Directories
BUILD_DIR := .build
FRAMEWORKS_DIR := Frameworks

# XCFramework targets
MBEDCRYPTO_XCF := $(FRAMEWORKS_DIR)/mbedcrypto.xcframework
MBEDTLS_XCF := $(FRAMEWORKS_DIR)/mbedtls.xcframework
MBEDX509_XCF := $(FRAMEWORKS_DIR)/mbedx509.xcframework
OPUS_XCF := $(FRAMEWORKS_DIR)/opus.xcframework
LIBCHIAKI_XCF := $(FRAMEWORKS_DIR)/libchiaki.xcframework
LIBPLACEBO_XCF := $(FRAMEWORKS_DIR)/libplacebo.xcframework
MOLTENVK_XCF := $(FRAMEWORKS_DIR)/MoltenVK.xcframework

# Default target
all: frameworks

# Build all frameworks
frameworks: mbedtls opus libchiaki
	@echo "✅ All xcframeworks built successfully"

# mbedtls (produces 3 xcframeworks)
mbedtls: $(MBEDCRYPTO_XCF)

$(MBEDCRYPTO_XCF):
	@echo "🔨 Building mbedtls..."
	@./Scripts/build_mbedtls.sh

# These are built together with mbedcrypto
$(MBEDTLS_XCF): $(MBEDCRYPTO_XCF)
$(MBEDX509_XCF): $(MBEDCRYPTO_XCF)

# opus
opus: $(OPUS_XCF)

$(OPUS_XCF):
	@echo "🔨 Building opus..."
	@./Scripts/build_opus.sh

# libchiaki (depends on mbedtls and opus - order-only to check existence only)
libchiaki: $(LIBCHIAKI_XCF)

$(LIBCHIAKI_XCF): | $(MBEDCRYPTO_XCF) $(OPUS_XCF)
	@echo "🔨 Building libchiaki..."
	@./Scripts/build_libchiaki.sh

# libplacebo + MoltenVK (T-243, built independently from libchiaki stack)
libplacebo: $(LIBPLACEBO_XCF) $(MOLTENVK_XCF)

$(LIBPLACEBO_XCF) $(MOLTENVK_XCF):
	@echo "🔨 Building libplacebo + MoltenVK..."
	@./Scripts/build-libplacebo.sh

# Clean everything
clean:
	@echo "🧹 Cleaning all build artifacts..."
	rm -rf $(BUILD_DIR)
	rm -rf $(FRAMEWORKS_DIR)/*.xcframework
	@echo "✅ Clean complete"

# Clean build cache only (keep xcframeworks for faster rebuilds)
clean-build:
	@echo "🧹 Cleaning build cache..."
	rm -rf $(BUILD_DIR)
	@echo "✅ Build cache cleaned"

# Initialize submodules
setup:
	@echo "📦 Initializing submodules..."
	git submodule update --init --recursive
	@echo "✅ Setup complete"


# Help
help:
	@echo "Chiaki Apple - Build System"
	@echo ""
	@echo "Build:"
	@echo "  make              - Build all xcframeworks"
	@echo "  make frameworks   - Same as above"
	@echo "  make mbedtls      - Build mbedtls xcframeworks only"
	@echo "  make opus         - Build opus xcframework only"
	@echo "  make libchiaki    - Build libchiaki xcframework only"
	@echo "  make libplacebo   - Build libplacebo + MoltenVK xcframeworks"
	@echo ""
	@echo "Maintenance:"
	@echo "  make setup        - Initialize git submodules"
	@echo "  make clean        - Remove all build artifacts"
	@echo "  make clean-build  - Remove build cache only"
	@echo "  make help         - Show this help"
	@echo ""
	@echo "Build order: mbedtls → opus → libchiaki"
