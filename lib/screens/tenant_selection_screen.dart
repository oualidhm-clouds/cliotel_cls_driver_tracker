import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/tenant_provider.dart';
import '../models/tenant.dart';
import '../config/theme.dart';
import 'login_screen.dart';

class TenantSelectionScreen extends StatefulWidget {
  const TenantSelectionScreen({super.key});

  @override
  State<TenantSelectionScreen> createState() => _TenantSelectionScreenState();
}

class _TenantSelectionScreenState extends State<TenantSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TenantProvider>().fetchTenants();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Tenant> _filterTenants(List<Tenant> tenants) {
    if (_searchQuery.isEmpty) return tenants;
    final q = _searchQuery.toLowerCase();
    return tenants
        .where((t) =>
            t.name.toLowerCase().contains(q) ||
            t.slug.toLowerCase().contains(q) ||
            (t.domain?.toLowerCase().contains(q) ?? false))
        .toList();
  }

  void _selectTenant(Tenant tenant) async {
    await context.read<TenantProvider>().selectTenant(tenant);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _BrandBadge(),
                  const SizedBox(height: 24),
                  Text(
                    'Select your hotel',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Choose the property you are assigned to. You can change it later from the login screen.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  // Search
                  TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search hotels',
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: AppColors.textMuted,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.close_rounded,
                                color: AppColors.textMuted,
                                size: 18,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ),

            // Tenant list
            Expanded(
              child: Consumer<TenantProvider>(
                builder: (context, provider, _) {
                  if (provider.status == TenantStatus.loading &&
                      provider.tenants.isEmpty) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 2,
                      ),
                    );
                  }

                  if (provider.status == TenantStatus.error &&
                      provider.tenants.isEmpty) {
                    return _buildErrorState(provider);
                  }

                  final filtered = _filterTenants(provider.tenants);
                  if (filtered.isEmpty) return _buildEmptyState();

                  return RefreshIndicator(
                    color: AppColors.primary,
                    backgroundColor: AppColors.surface,
                    onRefresh: () => provider.fetchTenants(),
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _TenantTile(
                        tenant: filtered[i],
                        onTap: () => _selectTenant(filtered[i]),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(TenantProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                size: 28,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Could not load hotels',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              provider.error ?? 'Please check your connection and try again.',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => provider.fetchTenants(),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try again'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.search_off_rounded,
              size: 28,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No hotels match your search',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Icon(
        Icons.business_rounded,
        size: 26,
        color: Colors.white,
      ),
    );
  }
}

class _TenantTile extends StatelessWidget {
  final Tenant tenant;
  final VoidCallback onTap;

  const _TenantTile({required this.tenant, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Center(
                  child: Text(
                    tenant.name.isEmpty
                        ? '?'
                        : tenant.name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryLight,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tenant.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tenant.domain ?? tenant.slug,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
