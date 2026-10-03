use anchor_lang::prelude::*;

declare_id!("CyD2G9sdMQnGm2GKnQJcEvMKQYdGiLB4mqurK1ustrHL");

#[program]
pub mod biotracer {
    use super::*;

    pub fn initialize_batch(ctx: Context<InitializeBatch>, batch_id: u32) -> Result<()> {
        let batch = &mut ctx.accounts.batch_account;
        batch.batch_id = batch_id;
        batch.status = 0; // 0 = Indústria
        batch.biotracer = *ctx.accounts.biotracer.key; // Salva a API como guardiã
        
        let clock = Clock::get()?;
        
        // Emite o log com o status da etapa (0) e a ação (0 = Aprovado/Criado)
        emit!(TraceEvent {
            batch_id,
            status: 0,
            action: 0, 
            node: *ctx.accounts.node.key,
            timestamp: clock.unix_timestamp,
        });

        Ok(())
    }

    pub fn update_status(ctx: Context<UpdateStatus>, new_status: u8, action: u8) -> Result<()> {
        require!(new_status <= 4, BioTracerError::InvalidStatus);
        
        // Garante que o fluxo sempre avança (não há processo reverso)
        require!(new_status > ctx.accounts.batch_account.status, BioTracerError::InvalidStatusTransition);

        let batch = &mut ctx.accounts.batch_account;
        batch.status = new_status;

        let clock = Clock::get()?;
        
        // Emite o log unificando em qual etapa ocorreu (status) e qual foi a ação (action)
        emit!(TraceEvent {
            batch_id: batch.batch_id,
            status: new_status,
            action, 
            node: *ctx.accounts.node.key,
            timestamp: clock.unix_timestamp,
        });

        Ok(())
    }
}

#[error_code]
pub enum BioTracerError {
    #[msg("Invalid status. Must be 0 (Indústria), 1 (Transporte), 2 (Hospital), 3 (Recusado), 4 (Descartado)")]
    InvalidStatus,
    #[msg("Status can only progress forward.")]
    InvalidStatusTransition,
}

#[account]
pub struct MedicineBatch {
    pub batch_id: u32,       // 4 bytes
    pub status: u8,          // 1 byte
    pub biotracer: Pubkey,   // 32 bytes - Chave da API que controla o lote
}

#[event]
pub struct TraceEvent {
    pub batch_id: u32,
    pub status: u8,          // Etapa da cadeia (0 a 4)
    pub action: u8,          // Resultado da etapa (ex: 0 = Aprovado, 1 = Reprovado)
    pub node: Pubkey,        // Quem assinou localmente
    pub timestamp: i64,
}

#[derive(Accounts)]
#[instruction(batch_id: u32)]
pub struct InitializeBatch<'info> {
    #[account(
        init, 
        payer = biotracer, 
        space = 8 + 4 + 1 + 32, // 45 bytes (Aumento mínimo para garantir segurança extrema)
        seeds = [b"batch", batch_id.to_le_bytes().as_ref()], 
        bump
    )]
    pub batch_account: Account<'info, MedicineBatch>,
    
    #[account(mut)]
    pub biotracer: Signer<'info>, // API da aplicação
    
    pub node: Signer<'info>, // Indústria assina localmente
    
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct UpdateStatus<'info> {
    #[account(
        mut,
        has_one = biotracer // Trava de segurança contra o Bypass via RPC
    )]
    pub batch_account: Account<'info, MedicineBatch>,
    
    #[account(mut)]
    pub biotracer: Signer<'info>, // API da aplicação precisa assinar
    
    pub node: Signer<'info>, // Transportadora ou Hospital assina localmente
}